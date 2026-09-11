#!/usr/bin/env python3
# hrv_monitor.py — 连续收 PPG 样本流，实时算 HR/HRV（数样本时基 + 中位数抗伪迹）
#   帧: FE E1 R0 R1 R2  (每帧=1个新样本, FPGA 已去重)
#   IBI = 两拍之间的样本数 / 实测采样率  → 用传感器时基，不用墙钟
# 用法: python3 hrv_monitor.py [设备] [秒数]
import sys, os, time, subprocess, math
import numpy as np

dev = sys.argv[1] if len(sys.argv) > 1 else "/dev/cu.usbserial-0001"
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 600.0

subprocess.run(["stty", "-f", dev, "9600", "raw"], check=False)
print(f"打开 {dev} @9600，记录 {dur:.0f}s …（手指/耳后轻搭住传感器，别使劲、别动）")
print("Ctrl-C 提前结束\n")

fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
buf = bytearray()
t_start = time.time()
last_report = t_start

csv = open("hrv_log.csv", "w")
csv.write("t,idx,red,beat,ibi_samples,ibi_ms\n")

# ---------- 峰检测状态 ----------
dc = None
sm = 0.0
emax = 0.0
emin = 0.0
d0 = d1 = d2 = 0.0
armed = True
last_beat_idx = None
raw_beats = []      # (idx, ibi_samples) 全部检测到的拍
idx = 0
n_samp = 0
sig_amp = 0.0

REFRA_S = 0.50     # 不应期 500ms（压下重搏波/重复触发）
WINDOW_S = 60.0    # HRV 窗口
DC_GATE = 20000    # DC 低于此 = 没耦合，不检测

def fs_actual():
    el = time.time() - t_start
    return (n_samp / el) if el > 1 else 100.0

def report(now):
    global last_report
    fs = fs_actual()
    dcs = dc if dc is not None else 0.0
    if not raw_beats:
        print(f"[{now-t_start:6.0f}s] 样本{n_samp} ({fs:.1f}/s)  DC={dcs:.0f} 幅度={sig_amp:.0f}  等待心跳…")
        last_report = now
        return
    cut = idx - int(WINDOW_S * fs)
    win = [b for (i, b) in raw_beats if i >= cut]
    if len(win) < 3:
        print(f"[{now-t_start:6.0f}s] 样本{n_samp} ({fs:.1f}/s)  DC={dcs:.0f} 幅度={sig_amp:.0f}  拍数不足({len(win)})")
        last_report = now
        return
    med = float(np.median(win))
    good = [b for b in win if 0.70 * med <= b <= 1.30 * med]   # 中位数 ±30%
    rej = len(win) - len(good)
    if len(good) < 3:
        print(f"[{now-t_start:6.0f}s] 样本{n_samp} ({fs:.1f}/s)  DC={dcs:.0f} 幅度={sig_amp:.0f}  有效拍不足")
        last_report = now
        return
    ibi_ms = np.array(good, float) / fs * 1000.0
    hr = 60000.0 / ibi_ms.mean()
    sdnn = ibi_ms.std(ddof=1)
    diff = np.diff(ibi_ms)
    rmssd = math.sqrt((diff ** 2).mean()) if len(diff) > 0 else 0.0
    q = "好" if (sdnn < 100 and rej < len(win) * 0.3) else ("中" if sdnn < 180 else "差")
    print(f"[{now-t_start:6.0f}s] HR={hr:5.1f}  RMSSD={rmssd:5.1f}  SDNN={sdnn:5.1f}  "
          f"有效{len(good):3d}/{len(win):3d}  采样{fs:5.1f}/s  DC={dcs:6.0f} 幅度={sig_amp:6.0f}  质量={q}")
    last_report = now

def process(red):
    """每来一个样本调用；返回是否检测到心跳"""
    global dc, sm, emax, emin, d0, d1, d2, armed, sig_amp
    x = float(red)
    if dc is None:
        dc = x
    ac = x - dc
    dc = dc + (x - dc) / 32.0        # 高通 ~0.5Hz @100sps
    if dc < DC_GATE:                 # DC 太低 = 没耦合 → 不检测
        armed = True
        return False
    sm = sm + (ac - sm) * 0.25        # 低通 ~4Hz
    d2 = d1; d1 = d0; d0 = sm
    if sm > emax: emax = sm
    else:         emax = emax - emax / 128.0
    if sm < emin: emin = sm
    else:         emin = emin + (-emin) / 128.0
    rng = emax - emin
    sig_amp = rng
    thr_hi = emin + (rng - rng / 4.0)   # 75%
    thr_lo = emin + rng / 4.0           # 25%
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

print(f"{'时间':>7}  HR     RMSSD   SDNN    有效/总     采样率     幅度     质量")
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
    ibi = np.array([b for (_, b) in raw_beats], float) / fs * 1000.0
    med = np.median(ibi)
    good = ibi[np.abs(ibi - med) <= 0.30 * med]
    print(f"总样本 {n_samp}, 检出拍 {len(raw_beats)}, 有效拍 {len(good)}, "
          f"中位IBI {med:.0f}ms → HR {60000/med:.1f}, "
          f"有效拍 HR {60000/good.mean():.1f}, RMSSD {math.sqrt((np.diff(good)**2).mean()):.1f}")
