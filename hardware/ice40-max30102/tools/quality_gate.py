#!/usr/bin/env python3
"""quality_gate.py — 采集质量门：判断一份 hrv_log.csv 能不能拿去建 S0 基线

为什么需要它：hrv_monitor 原来的"质量=好"只看"有效拍比例"，会漏掉
  · 漂移淹没脉搏（脉搏带能量占比极低）
  · 峰检测抖动主导（SDNN 随清洗口径漂）
  · 短窗自相关谐波误锁（HR 短窗在 122/77 之间跳）
这些真实发生过（见 FORGET.md / 采样率 100 vs 25 的坑）。

判据（阈值从真实会话标定，不是拍脑袋）：
  1. 帧率      95-105Hz              （固件输出 100Hz）
  2. 接触 DC   8万-21万              （FORGET.md: 10-15万好 / <8万太松 / ~26万饱和）
  3. 漂移/脉搏 < 6                   （好:4.2 / 噪:5.9 / 坏:60）
  4. 主峰落位  0.9-1.8Hz             （真实心率应在脉搏带）
  5. 检测率    >= 85%                （好:92 / 噪:91 / 坏:69）
  6. SDNN 跨清洗口径漂移 <= 10ms      （绝对量,不是比值——比值在低变异性信号上分母趋零误报）
  7. 自相关一致 >= 70% 段落在全窗±15%（防短窗谐波误锁）

用法：
  python3.14 quality_gate.py hrv_log.csv
"""
import sys, os, math
import numpy as np

# ---- 阈值（改这里调灵敏度）----
TH = dict(
    fs_lo=95, fs_hi=105, fs_warn=90,
    dc_lo=80000, dc_hi=210000, dc_warn_lo=60000, dc_warn_hi=240000,
    dp_pass=6.0, dp_warn=12.0,
    peak_lo=0.9, peak_hi=1.8,
    det_pass=0.85, det_warn=0.70,
    sdnn_pass=10.0, sdnn_warn=30.0,   # ms（跨清洗口径的绝对漂移）
    ac_pass=0.70, ac_warn=0.50,
)


def load_csv(path):
    ts, reds = [], []
    with open(path) as f:
        f.readline()
        for ln in f:
            p = ln.split(",")
            if len(p) >= 6:
                try:
                    ts.append(float(p[0])); reds.append(float(p[2]))
                except ValueError:
                    pass
    return np.array(ts), np.array(reds)


def trough_ibis(sm, fs, refr_s=0.40):
    """谷底基准点检测（与 hrv_monitor.py process() 同逻辑）。返回 IBI(ms) 数组。"""
    emax = emin = d0 = d1 = d2 = 0.0
    DEC = math.exp(-1.0 / (1.3 * fs))
    armed = True; last = None; ibis = []
    for i in range(1, len(sm)):
        cur = sm[i]; d2 = d1; d1 = d0; d0 = cur
        emax = cur if cur > emax else emax * DEC
        emin = cur if cur < emin else emin * DEC
        rng = emax - emin
        if rng <= 0:
            continue
        thr_hi = emin + rng * 0.75; thr_lo = emin + rng * 0.25
        refr_ok = (last is None) or ((i - last) > refr_s * fs)
        if not armed:
            if d1 > thr_hi:
                armed = True
        elif d1 < d0 and d1 < d2 and d1 < thr_lo and refr_ok:
            armed = False
            if last is not None:
                ibis.append((i - 1 - last) / fs * 1000.0)
            last = i - 1
    return np.array(ibis)


def _band(P, f, lo, hi):
    m = (f >= lo) & (f < hi)
    return float(P[m].sum())


def gate(ts, reds):
    """返回 dict：metrics + checks[(名, 级别, 值串, 说明)] + overall。级别 PASS/WARN/FAIL。"""
    n = len(reds)
    if n < 200:
        return dict(overall="FAIL", checks=[("数据量", "FAIL", f"{n}", "样本太少")], metrics={})
    fs = n / (ts[-1] - ts[0])
    x = np.asarray(reds, float)
    dc = float(x.mean())
    y = x - dc
    w = np.hanning(n)
    P = np.abs(np.fft.rfft(y * w)) ** 2
    f = np.fft.rfftfreq(n, 1.0 / fs)
    tot = _band(P, f, 0.05, 4.0) or 1e-9
    drift = _band(P, f, 0.05, 0.6) / tot
    pulse = _band(P, f, 1.0, 1.5) / tot
    dp = drift / max(pulse, 1e-9)
    b = (f >= 0.6) & (f <= 3.5)
    bf = f[b]; bs = np.abs(np.fft.rfft(y * w))[b]
    o = np.argsort(bs)[::-1]
    main_hz = float(bf[o[0]]); main_ratio = float(bs[o[0]] / bs[o[1]]) if len(bs) > 1 else 0.0

    # 预处理（同 hrv_monitor）
    A_HP = 1 - math.exp(-2 * math.pi * 0.5 / fs)
    A_LP = 1 - math.exp(-2 * math.pi * 4.0 / fs)
    dcv = None; sm = 0.0; S = np.empty(n)
    for i, xi in enumerate(x):
        if dcv is None:
            dcv = xi
        ac = xi - dcv; dcv += (ac) * A_HP
        sm += (ac - sm) * A_LP
        S[i] = sm
    ibis = trough_ibis(S, fs)

    dur = float(ts[-1] - ts[0])
    med = float(np.median(ibis)) if len(ibis) else 0.0
    hr = 60000.0 / med if med else 0.0
    expected = dur * 1000.0 / med if med else 1e9
    det = len(ibis) / expected if expected else 0.0

    def sdnn(thr):
        g = ibis[(ibis >= (1 - thr) * med) & (ibis <= (1 + thr) * med)]
        return float(g.std(ddof=1)) if len(g) > 2 else 0.0
    _sds = [sdnn(z) for z in (0.15, 0.20, 0.25, 0.30, 0.40, 0.50)]
    sd_lo = sdnn(0.20); sd_hi = sdnn(0.50)
    sd_spread = max(_sds) - min(_sds)   # ms：跨清洗口径 SDNN 的绝对漂移

    # 自相关一致性：30s 分段 HR 落在全窗 HR ±15% 的比例
    F = np.fft.rfft(y * np.hanning(n), 2 * n); rr = np.fft.irfft(F * np.conj(F))[:n]; rr /= rr[0] + 1e-9
    lo, hi = int(0.5 * fs), int(1.7 * fs)
    full_hr = 60.0 / ((lo + int(np.argmax(rr[lo:hi]))) / fs)
    good = tot_seg = 0
    for s in range(0, int(dur), 30):
        a = int(s * fs); b2 = int((s + 30) * fs)
        if b2 - a < 100 or b2 > n:
            continue
        seg = y[a:b2]; mm = len(seg)
        Fs = np.fft.rfft(seg * np.hanning(mm), 2 * mm); r2 = np.fft.irfft(Fs * np.conj(Fs))[:mm]; r2 /= r2[0] + 1e-9
        l2 = int(0.5 * fs) + int(np.argmax(r2[int(0.5 * fs):int(1.7 * fs)]))
        seg_hr = 60.0 / (l2 / fs)
        tot_seg += 1
        if abs(seg_hr - full_hr) / full_hr <= 0.15:
            good += 1
    ac = good / tot_seg if tot_seg else 0.0

    def lvl(v, lo_, hi_, wlo, whi):
        if lo_ <= v <= hi_:
            return "PASS"
        if wlo <= v <= whi:
            return "WARN"
        return "FAIL"

    checks = [
        ("帧率", lvl(fs, TH["fs_lo"], TH["fs_hi"], TH["fs_warn"], 1e9), f"{fs:.1f}Hz", "固件应 100Hz"),
        ("接触DC", lvl(dc, TH["dc_lo"], TH["dc_hi"], TH["dc_warn_lo"], TH["dc_warn_hi"]), f"{dc:.0f}", "8-21万=耦合好"),
        ("漂移/脉搏", "PASS" if dp <= TH["dp_pass"] else ("WARN" if dp <= TH["dp_warn"] else "FAIL"), f"{dp:.1f}", "越小越好(<6)"),
        ("主峰落位", "PASS" if TH["peak_lo"] <= main_hz <= TH["peak_hi"] else "WARN", f"{main_hz*60:.0f}BPM", "应在脉搏带"),
        ("检测率", "PASS" if det >= TH["det_pass"] else ("WARN" if det >= TH["det_warn"] else "FAIL"), f"{det*100:.0f}%", ">=85%"),
        ("SDNN稳定", "PASS" if sd_spread <= TH["sdnn_pass"] else ("WARN" if sd_spread <= TH["sdnn_warn"] else "FAIL"), f"{sd_spread:.0f}ms", "跨清洗口径漂移,越小越好"),
        ("自相关一致", "PASS" if ac >= TH["ac_pass"] else ("WARN" if ac >= TH["ac_warn"] else "FAIL"), f"{ac*100:.0f}%", "短窗与全窗一致"),
    ]
    order = {"PASS": 0, "WARN": 1, "FAIL": 2}
    overall = max((c[1] for c in checks), key=lambda l: order[l])
    metrics = dict(fs=fs, dc=dc, drift=drift, pulse=pulse, dp=dp, main_hz=main_hz,
                   main_ratio=main_ratio, hr=hr, det=det, sdnn_lo=sd_lo, sdnn_hi=sd_hi,
                   sd_spread=sd_spread, ac=ac, n_beat=len(ibis))
    return dict(overall=overall, checks=checks, metrics=metrics)


ICON = {"PASS": "OK  ", "WARN": "WARN", "FAIL": "FAIL"}


def print_gate(path):
    ts, reds = load_csv(path)
    r = gate(ts, reds)
    m = r.get("metrics", {})
    print(f"\n=== 质量门: {os.path.basename(path)} ===")
    for name, lvl, val, note in r["checks"]:
        print(f"  [{ICON[lvl]}] {name:10s} {val:>8s}   ({note})")
    if m:
        print(f"  ---- HR={m['hr']:.1f}  SDNN={m['sdnn_lo']:.0f}ms(±20%)/{m['sdnn_hi']:.0f}ms(±50%)  拍{m['n_beat']}")
    verdict = {"PASS": "✅ 可用——这份可以进基线",
               "WARN": "⚠️ 勉强——能用但会稀释基线，最好重采",
               "FAIL": "❌ 不可用——别进基线，重采"}[r["overall"]]
    print(f"  总评: {verdict}\n")
    return r["overall"]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
    else:
        print_gate(sys.argv[1])
