#!/usr/bin/env python3
# hrv_monitor.py — 连续收 PPG 样本流，实时算 HR + 长窗 SDNN（去 RMSSD）
#   帧: FE E1 R0 R1 R2  (每帧=1个新样本)
#   IBI = 两拍之间的样本数 / 实测采样率 （数样本时基）
#   滤波系数按采样率自动算（SMP_AVE=4 时 fs≈25）
# 用法: python3.14 hrv_monitor.py [设备] [秒数] [采样率Hz] [输出文件] [--meta "k=v,k=v"]
#   输出默认带时间戳 hrv_log_<日期>-<时间>.csv（每次会话一个文件，不覆盖）
#   --meta 写会话元数据 sidecar hrv_log_<…>.meta.json（协议参数/验收/派生量，见 s0-collection-protocol.md）
import sys, os, time, subprocess, math, json
import numpy as np
import quality_gate   # 复用同一检测器口径（不应期等），保证"采集端实时看到的" = "验收端事后存下的"


def _auto(v):
    s = v.strip(); low = s.lower()
    if low in ("true", "yes"):  return True
    if low in ("false", "no"):  return False
    for cast in (int, float):
        try: return cast(s)
        except ValueError: pass
    return s


def parse_meta(s):
    """--meta 的值：'k=v,k=v'（自动转 int/float/bool）；或 '@file.json' 读入。"""
    if not s:
        return {}
    if s.startswith("@"):
        with open(s[1:]) as f:
            return json.load(f)
    d = {}
    for kv in s.replace(";", ",").split(","):
        if "=" in kv:
            k, v = kv.split("=", 1)
            d[k.strip()] = _auto(v)
    return d


# 位置参数 [设备] [秒数] [采样率Hz] [输出文件] + 可选 --meta（顺序无关）
_argv = sys.argv[1:]
META_ARG, _pos = None, []
_i = 0
while _i < len(_argv):
    a = _argv[_i]
    if a == "--meta":
        _i += 1; META_ARG = _argv[_i] if _i < len(_argv) else ""
    elif a.startswith("--meta="):
        META_ARG = a.split("=", 1)[1]
    else:
        _pos.append(a)
    _i += 1

dev = _pos[0] if len(_pos) > 0 else "/dev/cu.usbserial-0001"
dur = float(_pos[1]) if len(_pos) > 1 else 600.0
FS  = float(_pos[2]) if len(_pos) > 2 else 25.0     # 采样率(SMP_AVE=4→25; 无平均→100)
# 输出文件名：默认带时间戳——攒 S0 基线要保留每次会话，绝不能互相覆盖
OUT = _pos[3] if len(_pos) > 3 else time.strftime("hrv_log_%Y%m%d-%H%M%S.csv")
user_meta = parse_meta(META_ARG)

subprocess.run(["stty", "-f", dev, "9600", "raw"], check=False)
print(f"打开 {dev} @9600，假定采样率 {FS:.0f}Hz，记录 {dur:.0f}s …（传感器贴稳，别使劲、别动）")
print("Ctrl-C 提前结束\n")

fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
buf = bytearray()
t_start = time.time()
last_report = t_start
warned_no_data = False   # 零数据告警只报一次
csv = open(OUT, "w")
csv.write("t,idx,red,beat,ibi_samples,ibi_ms\n")

# ---------- 按采样率算滤波系数 ----------
A_HP = 1 - math.exp(-2 * math.pi * 0.5 / FS)     # 高通 0.5Hz
A_LP = 1 - math.exp(-2 * math.pi * 4.0 / FS)     # 低通 4Hz
ENV_DECAY = math.exp(-1.0 / (1.3 * FS))          # 包络 ~1.3s

dc = None
sm = 0.0
emax = 0.0
emin = 0.0
d0 = d1 = d2 = 0.0
armed = True
last_beat_idx = None
raw_beats = []      # (idx, ibi_samples)
sm_hist = []        # 带通后的信号(算自相关)
idx = 0
n_samp = 0
sig_amp = 0.0

# MPU6050 加速度（FE E2）
acc_ax = acc_ay = acc_az = 0
acc_n = 0; acc_bad = 0          # 偏离 1g 超 0.1g 的样本数 → 运动占比
who_seen = None; who_printed = False

REFRA_S = quality_gate.REFR_S   # 不应期：引用质量门口径（现 0.40s），避免"采集端 vs 验收端"不一致
HR_WIN_S = 60.0     # HR 窗口
SDNN_WIN_S = 300.0  # SDNN 长窗
DC_GATE = 20000
STALL_S = 3.0        # 连续无新样本阈值(秒)：中途拔串口/板子停了要报警（不能静默录空到结束）
last_samp_t = t_start
first_samp_t = None
stall_warned = False
fs_warned = False

def fs_actual():
    el = time.time() - t_start
    return (n_samp / el) if el > 1 else FS

def _clean(win):
    if len(win) < 3:
        return [], len(win)
    med = float(np.median(win))
    good = [b for b in win if 0.70 * med <= b <= 1.30 * med]
    return good, len(win) - len(good)

FSR = 4.0   # 频域 HRV 重采样率(Hz)

def freq_hrv(pairs, fs):
    """频域 HRV：tachogram → 4Hz 重采样 → 去趋势 → FFT → LF/HF。pairs=[(idx,ibi_samples)]"""
    if len(pairs) < 60:
        return None
    t = np.array([i for (i, b) in pairs], float) / fs
    rr = np.array([b for (i, b) in pairs], float) / fs * 1000.0
    if t[-1] - t[0] < 120:      # 至少 2 分钟
        return None
    tu = np.arange(t[0], t[-1], 1.0 / FSR)
    rru = np.interp(tu, t, rr); rru = rru - rru.mean()
    x = np.arange(len(rru)); c = np.polyfit(x, rru, 1); rru = rru - (c[0] * x + c[1])  # 去线性趋势
    w = np.hanning(len(rru)); X = np.fft.rfft(rru * w); f = np.fft.rfftfreq(len(rru), 1.0 / FSR)
    P = np.abs(X) ** 2
    def band(lo, hi):
        m = (f >= lo) & (f < hi); return float(P[m].sum())
    lf = band(0.04, 0.15); hf = band(0.15, 0.40)
    if hf <= 0 or (lf + hf) <= 0:
        return None
    return lf, hf, lf / hf

def report(now):
    global last_report, warned_no_data, stall_warned, fs_warned
    fs = fs_actual()
    dcs = dc if dc is not None else 0.0
    accstr = f"  ACC=({acc_ax:6d},{acc_ay:6d},{acc_az:6d})" if acc_n else "  ACC=--(无MPU)"
    # 失联告警：中途掉串口/板子停——不能只在"从没收到过"时报（那会静默录空到 dur 结束）
    if n_samp > 0 and (now - last_samp_t) > STALL_S and not stall_warned:
        stall_warned = True
        print(f"  ⚠⚠ 已 {now - last_samp_t:.0f}s 没有新样本——串口断了/板子停了？"
              f"建议 Ctrl-C 存盘退出，检查后再采")
    # 帧率漂移告警：滤波系数/IBI 换算是启动时按 FS 一次性算的；实测漂太多则实时结果不可信。
    # 用「首末样本跨度」估帧率（排除启动空窗），且样本够了才判，避免开机瞬间误报。
    span = (last_samp_t - first_samp_t) if first_samp_t is not None else 0.0
    if span > 5.0 and n_samp > 300:
        fs_span = (n_samp - 1) / span
        if abs(fs_span - FS) / FS > 0.05:
            if not fs_warned:
                fs_warned = True
                print(f"  ⚠ 实测帧率 {fs_span:.1f}/s 与假定 {FS:.0f}/s 偏差 >5%——时基可疑，实时结果别信")
        else:
            fs_warned = False
    # 自相关出 HR + 质量 r（稳健）
    ac_hr = float('nan'); ac_r = 0.0
    if len(sm_hist) > int(fs * 15):
        w = np.array(sm_hist[-int(fs * 40):], float); w = w - w.mean(); m = len(w)
        F = np.fft.rfft(w * np.hanning(m), 2 * m); rr = np.fft.irfft(F * np.conj(F))[:m]
        rr = rr / (rr[0] + 1e-9)
        lo, hi = int(0.50 * fs), int(1.60 * fs)
        lag = lo + int(np.argmax(rr[lo:hi])); ac_r = float(rr[lag])
        if ac_r > 0.25: ac_hr = 60.0 / (lag / fs)
    ach = f"{ac_hr:4.0f}(r{ac_r:.2f})" if ac_hr == ac_hr else f"  --(r{ac_r:.2f})"
    hint = "  ⚠ DC偏低=接触弱" if dcs < 80000 else ("  ⚠ DC近饱和" if dcs > 210000 else "")
    if not raw_beats or len(sm_hist) < int(fs * 15):
        print(f"[{now-t_start:6.0f}s] 样本{n_samp} ({fs:.1f}/s)  DC={dcs:.0f} 幅度={sig_amp:.0f}  HR(自相关)={ach}  等待…{hint}{accstr}")
        # 零数据告警：板子/固件没起来时别傻等——直接给诊断（2026-09-12 丢固件那次踩的坑）
        if n_samp == 0 and (now - t_start) > 8 and not warned_no_data:
            warned_no_data = True
            print("  ⚠⚠ 8 秒零样本——FPGA 很可能丢了固件（上电/重插会清掉 SRAM 配置）")
            print("     处置：把 hardware/ice40/ice40-max30102/max30102_stream.bin 拖到 iCELink 盘重烧")
            print("     佐证：传感器红灯灭 = I2C 没跑；重烧仍无数据 → 换串口（usbmodem*）试")
        last_report = now; return
    hr_win = [(i, b) for (i, b) in raw_beats if i >= idx - int(HR_WIN_S * fs)]
    sd_win = [(i, b) for (i, b) in raw_beats if i >= idx - int(SDNN_WIN_S * fs)]
    hr_good, hr_rej = _clean([b for (i, b) in hr_win])
    hr = 60000.0 / (float(np.mean(hr_good)) / fs * 1000.0) if len(hr_good) >= 3 else float('nan')
    sd_vals = [b for (i, b) in sd_win]
    sd_good, _ = _clean(sd_vals)
    sdnn = (np.array(sd_good, float) / fs * 1000.0).std(ddof=1) if len(sd_good) > 2 else 0.0
    # 频域 HRV（用清洗后的拍）
    if len(sd_vals) >= 3:
        meds = float(np.median(sd_vals))
        sd_pairs = [(i, b) for (i, b) in sd_win if 0.70 * meds <= b <= 1.30 * meds]
    else:
        sd_pairs = []
    fhr = freq_hrv(sd_pairs, fs)
    if fhr:
        lf, hf, ratio = fhr; lfnu = lf / (lf + hf) * 100.0
        fstr = f"LF/HF={ratio:.2f}  LFnu={lfnu:.0f} HFnu={100-lfnu:.0f}"
    else:
        fstr = "LF/HF=-- (需≥2min有效拍)"
    # 窗口剔除率（忠实名）。开场窗未满时它天然偏高（中位不稳+启动瞬态）= 预热假象——
    # 旧版把这误标成"质量=差"，会骗人。窗未满就不显示；权威验收看末尾 quality_gate。
    q = "--(预热)" if len(hr_win) < 30 else f"{hr_rej / len(hr_win) * 100:.0f}%"
    hpk = f"{hr:5.1f}" if hr == hr else "  -- "
    accstr = f"  ACC=({acc_ax:6d},{acc_ay:6d},{acc_az:6d})" if acc_n else "  ACC=--(无MPU)"
    print(f"[{now-t_start:6.0f}s] HR(谷)={hpk}  HR(自相关)={ach}  SDNN(5min)={sdnn:4.0f}  "
          f"HR有效{len(hr_good):3d}/{len(hr_win):3d}  采样{fs:5.1f}/s  DC={dcs:6.0f} 幅度={sig_amp:6.0f}  窗剔除={q}{hint}{accstr}")
    print(f"          频域HRV: {fstr}   (拍/5min={len(sd_pairs)})")
    last_report = now

def process(red):
    global dc, sm, emax, emin, d0, d1, d2, armed, sig_amp
    x = float(red)
    if dc is None:
        dc = x
    ac = x - dc
    dc = dc + (x - dc) * A_HP
    if dc < DC_GATE:
        armed = True
        return False
    sm = sm + (ac - sm) * A_LP
    sm_hist.append(sm)
    if len(sm_hist) > 8000: del sm_hist[:2000]
    d2 = d1; d1 = d0; d0 = sm
    if sm > emax: emax = sm
    else:         emax *= ENV_DECAY
    if sm < emin: emin = sm
    else:         emin *= ENV_DECAY
    rng = emax - emin
    sig_amp = rng
    thr_hi = emin + (rng - rng / 4.0)
    thr_lo = emin + rng / 4.0
    fs = fs_actual()
    refr_ok = (last_beat_idx is None) or ((idx - last_beat_idx) > REFRA_S * fs)
    beat = False
    # 基准点 = 谷底(local min)，不是峰值——FORGET.md P1#2 处方：
    #   峰值有宽平顶 + 重搏波 → 峰位抖 ±几十ms → RMSSD/SDNN 虚高。
    #   谷底更尖更稳。真实数据回放实测：抖动 16.7%→9.1%，SDNN 89→58ms，RMSSD 138→55ms。
    if not armed:
        if d1 > thr_hi:
            armed = True
    elif (d1 < d0) and (d1 < d2) and (d1 < thr_lo) and refr_ok:
        armed = False
        beat = True
    return beat

print(f"{'时间':>7}  HR     SDNN(5min)  HR有效/总     采样率     DC     幅度    窗剔除")
try:
    while True:
        now = time.time()
        if now - t_start >= dur:
            break
        try:
            chunk = os.read(fd, 8192)
        except (BlockingIOError, OSError):
            chunk = b""
        if chunk:
            buf.extend(chunk)
            while len(buf) >= 3:
                if buf[0] == 0xFE and buf[1] == 0xE1:
                    if len(buf) < 5: break          # 半帧 → 等下一批，绝不能删（删了会丢帧/错位）
                    r = ((buf[2] & 0x03) << 16) | (buf[3] << 8) | buf[4]
                    del buf[:5]
                    idx += 1
                    n_samp += 1
                    last_samp_t = now      # 有新样本 → 重置失联计时
                    if first_samp_t is None: first_samp_t = now
                    stall_warned = False
                    beat = process(r)
                    ibi_samples = 0
                    if beat:
                        if last_beat_idx is not None:
                            ibi_samples = idx - last_beat_idx
                            raw_beats.append((idx, ibi_samples))
                        last_beat_idx = idx
                    ibi_ms = ibi_samples / fs_actual() * 1000.0 if ibi_samples else 0.0
                    csv.write(f"{now:.3f},{idx},{r},{1 if beat else 0},"
                              f"{ibi_samples},{ibi_ms:.1f}\n")
                elif buf[0] == 0xFE and buf[1] == 0xE2:
                    if len(buf) < 8: break
                    ax = (buf[2] << 8) | buf[3]; ax -= 65536 if ax >= 32768 else 0   # 大端(i16)
                    ay = (buf[4] << 8) | buf[5]; ay -= 65536 if ay >= 32768 else 0
                    az = (buf[6] << 8) | buf[7]; az -= 65536 if az >= 32768 else 0
                    del buf[:8]
                    acc_ax, acc_ay, acc_az = ax, ay, az
                    mag = math.sqrt(ax*ax + ay*ay + az*az)
                    acc_n += 1
                    if abs(mag - 16384.0) > 1638.0: acc_bad += 1   # ±2g: 16384 LSB/g；偏离 1g >0.1g
                elif buf[0] == 0xFE and buf[1] == 0xE3:
                    who_seen = buf[2]; del buf[:3]
                    if not who_printed:
                        who_printed = True
                        print(f"  [MPU] WHO_AM_I = 0x{who_seen:02x}  " +
                              ("OK" if who_seen == 0x68 else "**异常：检查 MPU 接线 / AD0 是否接 GND**"))
                else:
                    del buf[:1]
        else:
            time.sleep(0.002)
        if now - last_report >= 2.0:
            report(now)
finally:
    os.close(fd)
    csv.close()

report(time.time())
print(f"\n已存 {OUT}")

hr_final = sdnn_final = None
if raw_beats:
    fs = fs_actual()
    all_ibi = np.array([b for (_, b) in raw_beats], float) * 1000.0 / fs
    good, _ = _clean(list(all_ibi))
    g = np.array(good, float)
    hr_final, sdnn_final = 60000.0 / g.mean(), float(g.std(ddof=1))
    print(f"总样本 {n_samp}, 检出拍 {len(raw_beats)}, 有效 {len(g)}, "
          f"HR {hr_final:.1f}, SDNN {sdnn_final:.0f}ms")

# 采集质量门：判断这份数据能不能进 S0 基线（不合格就别拿去建基线）
verdict, gate_dict = None, None
try:
    import quality_gate
    verdict = quality_gate.print_gate(OUT)
    gate_dict = quality_gate.gate(*quality_gate.load_csv(OUT))
except Exception as e:
    print(f"(质量门跳过: {e}；可单独跑 python3.14 quality_gate.py {OUT})")

# 会话元数据 sidecar（--meta）：协议参数 + 验收 + 派生量 —— 供 baseline 判断"两次会话是否同条件"
if META_ARG is not None:
    meta = {
        "session_id": time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(t_start)),
        "csv": os.path.basename(OUT),
        "protocol": {
            "device": "iCESugar+MAX30102", "fw": "max30102_stream.bin",
            "fs_nominal": FS, "baud": 9600, "led_ma": 7.2,
            "site": "finger", "fixation": "tape", "light_blocked": True,
            "posture": None, "dur_s": dur,
            **user_meta,          # --meta 覆盖/补充（如 posture=sitting,since_meal_min=120）
        },
        "quality": {
            "gate": verdict,
            "checks": ({n: l for n, l, _, _ in gate_dict["checks"]} if gate_dict else None),
            "dc_mean": round(dc, 0) if dc is not None else None,
            "fs_measured": round(fs_actual(), 1),
            "motion_pct": round(acc_bad / acc_n * 100.0, 1) if acc_n else None,
        },
        "derived": {
            "hr": round(hr_final, 2) if hr_final else None,
            "sdnn": round(sdnn_final, 2) if sdnn_final is not None else None,
            "n_beat": len(raw_beats), "n_samp": n_samp,
        },
    }
    mp = os.path.splitext(OUT)[0] + ".meta.json"
    with open(mp, "w") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(f"已存元数据 {mp}")
