#!/usr/bin/env python3
# ppg_capture.py — 抓 MAX30102 原始 PPG，带通 + FFT 找心跳
# 用法: python3 ppg_capture.py [设备] [秒数]
#   例: python3 ppg_capture.py /dev/cu.usbserial-0001 20
import sys, os, time, subprocess
import numpy as np

dev = sys.argv[1] if len(sys.argv) > 1 else "/dev/cu.usbserial-0001"
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 20.0

subprocess.run(["stty", "-f", dev, "9600", "raw"], check=False)

print(f"打开 {dev}，抓 {dur:.0f} 秒 …（手指按在 MAX30102 上，保持不动、力度均匀）")
fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
buf = bytearray()
t0 = time.time()
try:
    while time.time() - t0 < dur:
        try:
            chunk = os.read(fd, 4096)
            if chunk:
                buf.extend(chunk)
        except (BlockingIOError, OSError):
            pass
        time.sleep(0.003)
finally:
    os.close(fd)

# 切帧: FE E1 + 6 字节
data = bytes(buf)
reds, irs = [], []
i, n = 0, len(data)
while i + 8 <= n:
    if data[i] == 0xFE and data[i + 1] == 0xE1:
        r  = ((data[i + 2] & 0x03) << 16) | (data[i + 3] << 8) | data[i + 4]
        ir = ((data[i + 5] & 0x03) << 16) | (data[i + 6] << 8) | data[i + 7]
        reds.append(r); irs.append(ir)
        i += 8
    else:
        i += 1

red = np.array(reds, float)
ir  = np.array(irs,  float)
nf = len(red)
print(f"收到 {len(data)} 字节，解析出 {nf} 帧，平均 {nf/dur:.1f} 帧/秒")
if nf < 40:
    print("帧数太少"); sys.exit(1)

print(f"RED  DC均值={red.mean():.0f}  范围={red.min():.0f}~{red.max():.0f}  ACpp={red.max()-red.min():.0f}")
print(f"IR   DC均值={ir.mean():.0f}  范围={ir.min():.0f}~{ir.max():.0f}  ACpp={ir.max()-ir.min():.0f}")

with open("ppg_capture.csv", "w") as f:
    f.write("idx,red,ir\n")
    for k in range(nf):
        f.write(f"{k},{int(red[k])},{int(ir[k])}\n")
print("已存 ppg_capture.csv")

fs = nf / dur
freqs = np.fft.rfftfreq(nf, d=1.0 / fs)
band = (freqs >= 0.6) & (freqs <= 3.5)

def analyze(x, name):
    # 带通 0.6~3.5Hz（FFT 频域）拿脉搏 AC
    y = x - x.mean()
    Y = np.fft.rfft(y)
    Yb = Y.copy(); Yb[~band] = 0
    ac = np.fft.irfft(Yb, n=nf)
    # 频谱用 Hann 窗减少泄漏
    w = np.hanning(nf)
    spec = np.abs(np.fft.rfft(y * w))
    bf = freqs[band]
    order = np.argsort(spec[band])[::-1]
    print(f"\n[{name}] 候选主频（前 5）:")
    for k in order[:5]:
        print(f"  {bf[k]:5.2f} Hz = {bf[k]*60:5.0f} BPM   幅度 {spec[band][k]:8.0f}")
    print(f"[{name}] → 主频 {bf[order[0]]:.2f}Hz = {bf[order[0]]*60:.0f} BPM")
    return ac, bf[order[0]]

print(f"\n采样率≈{fs:.1f}Hz  频率分辨率≈{fs/nf:.3f}Hz")
ac, pk = analyze(red, "RED")
analyze(ir, "IR")

# ASCII 波形（带通后的 RED；显示中间 ~8 秒）
seg = ac
if nf > int(fs * 8):
    c = nf // 2
    seg = ac[c - int(fs * 4): c + int(fs * 4)]
mx = np.max(np.abs(seg)) or 1.0
rows, cols = 15, 100
step = max(1, len(seg) // cols)
print(f"\nRED 带通(0.6~3.5Hz) 波形 (1格≈{step/fs*1000:.0f}ms):")
for r in range(rows, -1, -1):
    yy = (r / rows) * 2 - 1
    line = ""
    for c2 in range(0, len(seg) - step + 1, step):
        v = seg[c2:c2 + step].mean() / mx
        line += "*" if abs(v - yy) < (2.0 / rows) else " "
    print(line)
