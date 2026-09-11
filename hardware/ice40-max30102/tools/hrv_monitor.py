#!/usr/bin/env python3
# hrv_monitor.py — 连续收 PPG 样本流，实时算 HR + 长窗 SDNN（去 RMSSD）
#   帧: FE E1 R0 R1 R2  (每帧=1个新样本)
#   IBI = 两拍之间的样本数 / 实测采样率 （数样本时基）
#   滤波系数按采样率自动算（SMP_AVE=4 时 fs≈25）
# 用法: python3 hrv_monitor.py [设备] [秒数] [采样率Hz]
import sys, os, time, subprocess, math
import numpy as np

dev = sys.argv[1] if len(sys.argv) > 1 else "/dev/cu.usbserial-0001"
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 600.0
FS  = float(sys.argv[3]) if len(sys.argv) > 3 else 25.0     # 采样率(SMP_AVE=4→25; 无平均→100)

subprocess.run(["stty", "-f", dev, "9600", "raw"], check=False)
print(f"打开 {dev} @9600，假定采样率 {FS:.0f}Hz，记录 {dur:.0f}s …（传感器贴稳，别使劲、别动）")
print("Ctrl-C 提前结束\n")

fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
buf = bytearray()
t_start = time.time()
last_report = t_start
csv = open("hrv_log.csv", "w")
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

REFRA_S = 0.50      # 不应期 500ms
HR_WIN_S = 60.0     # HR 窗口
SDNN_WIN_S = 300.0  # SDNN 长窗
DC_GATE = 20000

def fs_actual():
    el = time.time() - t_start
    return (n_samp / el) if el > 1 else FS

def _clean(win):
    if len(win) < 3:
        return [], len(win)
    med = float(np.median(win))
    good = [b for b in win if 0.70 * med <= b <= 1.30 * med]
    return good, len(win) - len(good)

def report(now):
    global last_report
    fs = fs_actual()
    dcs = dc if dc is not None else 0.0
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
        print(f"[{now-t_start:6.0f}s] 样本{n_samp} ({fs:.1f}/s)  DC={dcs:.0f} 幅度={sig_amp:.0f}  HR(自相关)={ach}  等待…{hint}")
        last_report = now; return
    hr_win = [b for (i, b) in raw_beats if i >= idx - int(HR_WIN_S * fs)]
    sd_win = [b for (i, b) in raw_beats if i >= idx - int(SDNN_WIN_S * fs)]
    hr_good, hr_rej = _clean(hr_win)
    hr = 60000.0 / (float(np.mean(hr_good)) / fs * 1000.0) if len(hr_good) >= 3 else float('nan')
    sd_good, _ = _clean(sd_win)
    sdnn = (np.array(sd_good, float) / fs * 1000.0).std(ddof=1) if len(sd_good) > 2 else 0.0
    q = "好" if (hr_rej < len(hr_win) * 0.25) else ("中" if hr_rej < len(hr_win) * 0.45 else "差")
    hpk = f"{hr:5.1f}" if hr == hr else "  -- "
    print(f"[{now-t_start:6.0f}s] HR(峰)={hpk}  HR(自相关)={ach}  SDNN(5min)={sdnn:4.0f}  "
          f"HR有效{len(hr_good):3d}/{len(hr_win):3d}  采样{fs:5.1f}/s  DC={dcs:6.0f} 幅度={sig_amp:6.0f}  质量={q}{hint}")
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
    if not armed:
        if d1 < thr_lo:
            armed = True
    elif (d1 > d0) and (d1 > d2) and (d1 > thr_hi) and refr_ok:
        armed = False
        beat = True
    return beat

print(f"{'时间':>7}  HR     SDNN(5min)  HR有效/总     采样率     DC     幅度     质量")
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
            while len(buf) >= 5:
                if buf[0] == 0xFE and buf[1] == 0xE1:
                    r = ((buf[2] & 0x03) << 16) | (buf[3] << 8) | buf[4]
                    del buf[:5]
                    idx += 1
                    n_samp += 1
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
print("\n已存 hrv_log.csv")
if raw_beats:
    fs = fs_actual()
    all_ibi = np.array([b for (_, b) in raw_beats], float) * 1000.0 / fs
    good, _ = _clean(list(all_ibi))
    g = np.array(good, float)
    print(f"总样本 {n_samp}, 检出拍 {len(raw_beats)}, 有效 {len(g)}, "
          f"HR {60000/g.mean():.1f}, SDNN {g.std(ddof=1):.0f}ms")
