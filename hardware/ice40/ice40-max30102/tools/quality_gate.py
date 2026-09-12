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
  3. 漂移/脉搏 < 10                  （实数据标定：好 3.6/4.2/6.3，坏 18.7；脉搏带随实测 HR 自适应）
  4. 主峰落位  0.9-1.8Hz             （真实心率应在脉搏带）
  5. 检测率    >= 85%                （好:92 / 噪:91 / 坏:69）
  6. SDNN 跨清洗口径漂移 <= 10ms      （绝对量,不是比值——比值在低变异性信号上分母趋零误报）
  7. 节律强度 >= 0.50              （各 30s 窗自相关峰 r 的中位数；防短窗谐波误锁）
  8. 运动窗占比 <= 10%             （逐 30s 窗 |a| 偏离 1g 算运动；需 CSV 带 ax,ay,az，否则 N/A）

用法：
  python3.14 quality_gate.py hrv_log.csv
"""
import sys, os, math
import numpy as np

# ---- 阈值（改这里调灵敏度）----
TH = dict(
    fs_lo=95, fs_hi=105, fs_warn=90,
    dc_lo=80000, dc_hi=210000, dc_warn_lo=60000, dc_warn_hi=240000,
    dp_pass=10.0, dp_warn=15.0,   # 依实数据标定(2026-09-12)：好会话 3.6/4.2/6.3，坏会话 18.7
    peak_lo=0.9, peak_hi=1.8,
    det_pass=0.85, det_warn=0.70,
    sdnn_pass=10.0, sdnn_warn=30.0,   # ms（跨清洗口径的绝对漂移）
    rhythm_pass=0.50, rhythm_warn=0.30,  # 各30s窗自相关峰r的中位数
)


def load_csv(path):
    ts, reds, acc = [], [], []
    with open(path) as f:
        f.readline()
        for ln in f:
            p = ln.split(",")
            if len(p) >= 6:
                try:
                    ts.append(float(p[0])); reds.append(float(p[2]))
                    if len(p) >= 9:
                        acc.append((float(p[6]), float(p[7]), float(p[8])))
                except ValueError:
                    pass
    if len(acc) == len(ts) and len(acc) > 0:
        return np.array(ts), np.array(reds), np.array(acc)
    return np.array(ts), np.array(reds), None


REFR_S = 0.40   # 谷底不应期(秒)。检测器的唯一可调参数——hrv_monitor 直接引用它，
                # 保证「采集端实时看到的」与「验收端事后存下的」同口径（曾 0.50 vs 0.40 不一致）。


def trough_ibis(sm, fs, refr_s=REFR_S):
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


def detect_from_red(reds, fs):
    """从原始 red 序列检测拍间期（谷底基准点，与 hrv_monitor.process 同逻辑）。

    关键纪律：baseline / quality_gate 都必须走这里重新检测——
    绝不能信 CSV 里存的 beat/ibi 列：那是采集时哪个版本的检测器写的就是哪个，
    跨检测器版本的会话会因此不可比（SDNN 的差异来自代码而非生理）。"""
    A_HP = 1 - math.exp(-2 * math.pi * 0.5 / fs)
    A_LP = 1 - math.exp(-2 * math.pi * 4.0 / fs)
    dcv = None; sm = 0.0; S = np.empty(len(reds))
    for i, xi in enumerate(reds):
        if dcv is None:
            dcv = xi
        ac = xi - dcv; dcv += ac * A_HP
        sm += (ac - sm) * A_LP
        S[i] = sm
    return trough_ibis(S, fs)


def _band(P, f, lo, hi):
    m = (f >= lo) & (f < hi)
    return float(P[m].sum())


def gate(ts, reds, acc=None):
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

    # 预处理 + 谷底检测（从 red 重来，不信 CSV 存的 beat 列）
    # 先检测，才能让下面「脉搏带」跟着实际 HR 走，而不是写死 1.0–1.5Hz(60–90bpm)。
    ibis = detect_from_red(x, fs)
    dur = float(ts[-1] - ts[0])
    med = float(np.median(ibis)) if len(ibis) else 0.0
    gic = ibis[(ibis >= 0.70 * med) & (ibis <= 1.30 * med)] if med else np.array([])
    hr = 60000.0 / float(np.mean(gic)) if len(gic) else 0.0   # 与 hrv_monitor/baseline 同口径：0.7~1.3 清洗后取均值（勿再用 median）
    expected = dur * 1000.0 / med if med else 1e9
    det = len(ibis) / expected if expected else 0.0

    b = (f >= 0.6) & (f <= 3.5)
    bf = f[b]; bs = np.abs(np.fft.rfft(y * w))[b]
    o = np.argsort(bs)[::-1]
    main_hz = float(bf[o[0]]); main_ratio = float(bs[o[0]] / bs[o[1]]) if len(bs) > 1 else 0.0

    # 「漂移/脉搏」的脉搏带 = max(0.6, 0.8·f_hr) ~ 1.2·f_hr，随实测 HR 自适应(±20%)。
    # 写死 1.0–1.5Hz 时，HR<60 或 >90 → 脉搏带能量塌陷 → dp 爆表(≈7.5e4) → 好数据被误判 FAIL。
    f_hr = (1000.0 / med) if med > 0 else main_hz
    pulse_lo, pulse_hi = max(0.6, 0.8 * f_hr), 1.2 * f_hr
    pulse = _band(P, f, pulse_lo, pulse_hi) / tot if pulse_hi > pulse_lo else 0.0
    drift = _band(P, f, 0.05, 0.6) / tot
    dp = drift / max(pulse, 1e-9)

    def sdnn(thr):
        g = ibis[(ibis >= (1 - thr) * med) & (ibis <= (1 + thr) * med)]
        return float(g.std(ddof=1)) if len(g) > 2 else 0.0
    _sds = [sdnn(z) for z in (0.15, 0.20, 0.25, 0.30, 0.40, 0.50)]
    sd_lo = sdnn(0.30); sd_hi = sdnn(0.50)   # ±30% = hrv_monitor/baseline 的 0.7~1.3 口径，三处必须一致
    sd_spread = max(_sds) - min(_sds)   # ms：跨清洗口径 SDNN 的绝对漂移

    # 节律强度 = 各 30s 窗自相关峰 r 的中位数（衡量"脉搏周期是否清晰"）。
    # 2026-09-12 修正：原用"各窗 HR vs 全窗 HR 一致率"，但**全窗自相关在 HR 随时间变化时
    # 会失去内部峰**（argmax 落到搜索边界 = 纯伪影）——该指标会把"HR 正常波动"误判成
    # "估计不可靠"，误杀好数据（实测一份窗剔除0%、r≈0.99 的好数据被判 FAIL 33%）。
    rs = []
    for s in range(0, int(dur), 30):
        a = int(s * fs); b2 = int((s + 30) * fs)
        if b2 - a < 100 or b2 > n:
            continue
        seg = y[a:b2]; mm = len(seg)
        Fs = np.fft.rfft(seg * np.hanning(mm), 2 * mm); r2 = np.fft.irfft(Fs * np.conj(Fs))[:mm]; r2 /= r2[0] + 1e-9
        l2 = int(0.5 * fs) + int(np.argmax(r2[int(0.5 * fs):int(1.7 * fs)]))
        rs.append(float(r2[l2]))
    rhythm = float(np.median(rs)) if rs else 0.0

    def lvl(v, lo_, hi_, wlo, whi):
        if lo_ <= v <= hi_:
            return "PASS"
        if wlo <= v <= whi:
            return "WARN"
        return "FAIL"

    # 运动窗：逐 30s 窗算"运动样本占比"（|a| 偏离 1g >0.1g）。需 CSV 带 ax,ay,az 列，否则 N/A。
    motion_frac = None; motion_win_max = None
    if acc is not None and len(acc) == len(reds) and len(reds) > 0:
        mag = np.sqrt((np.asarray(acc, float) ** 2).sum(axis=1))
        moving = np.abs(mag - 16384.0) > 1638.0
        wins = []; s0 = float(ts[0])
        while s0 + 30.0 <= float(ts[-1]):
            m = (ts >= s0) & (ts < s0 + 30.0)
            if m.sum() > 0: wins.append(float(moving[m].mean()))
            s0 += 30.0
        if wins:
            motion_win_max = max(wins)
            motion_frac = float(np.mean([w > 0.2 for w in wins]))

    checks = [
        ("帧率", lvl(fs, TH["fs_lo"], TH["fs_hi"], TH["fs_warn"], 1e9), f"{fs:.1f}Hz", "固件应 100Hz"),
        ("接触DC", lvl(dc, TH["dc_lo"], TH["dc_hi"], TH["dc_warn_lo"], TH["dc_warn_hi"]), f"{dc:.0f}", "8-21万=耦合好"),
        ("漂移/脉搏", "PASS" if dp <= TH["dp_pass"] else ("WARN" if dp <= TH["dp_warn"] else "FAIL"), f"{dp:.1f}", "越小越好(<10)"),
        ("主峰落位", "PASS" if TH["peak_lo"] <= main_hz <= TH["peak_hi"] else "WARN", f"{main_hz*60:.0f}BPM", "应在脉搏带"),
        ("检测率", "PASS" if det >= TH["det_pass"] else ("WARN" if det >= TH["det_warn"] else "FAIL"), f"{det*100:.0f}%", ">=85%"),
        ("SDNN稳定", "PASS" if sd_spread <= TH["sdnn_pass"] else ("WARN" if sd_spread <= TH["sdnn_warn"] else "FAIL"), f"{sd_spread:.0f}ms", "跨清洗口径漂移,越小越好"),
        ("节律强度", "PASS" if rhythm >= TH["rhythm_pass"] else ("WARN" if rhythm >= TH["rhythm_warn"] else "FAIL"), f"{rhythm:.2f}", "各窗自相关峰r中位(>0.5清晰)"),
        ("运动", ("N/A" if motion_frac is None else ("PASS" if motion_frac <= 0.1 else ("WARN" if motion_frac <= 0.3 else "FAIL"))),
         (f"{motion_frac*100:.0f}%" if motion_frac is not None else "--"), "运动窗占比(逐30s,>0.2算运动)"),
    ]
    order = {"N/A": -1, "PASS": 0, "WARN": 1, "FAIL": 2}
    overall = max((c[1] for c in checks), key=lambda l: order[l])
    metrics = dict(fs=fs, dc=dc, drift=drift, pulse=pulse, dp=dp, main_hz=main_hz,
                   main_ratio=main_ratio, hr=hr, det=det, sdnn_lo=sd_lo, sdnn_hi=sd_hi,
                   sd_spread=sd_spread, rhythm=rhythm, n_beat=len(ibis),
                   motion_frac=motion_frac, motion_win_max=motion_win_max)
    return dict(overall=overall, checks=checks, metrics=metrics)


ICON = {"PASS": "OK  ", "WARN": "WARN", "FAIL": "FAIL", "N/A": " -- "}


def print_gate(path):
    if not os.path.exists(path):
        print(f"\n找不到文件：{path}（检查路径；或先 python3.14 hrv_monitor.py 采集）")
        return "FAIL"
    ts, reds, acc = load_csv(path)
    r = gate(ts, reds, acc)
    m = r.get("metrics", {})
    print(f"\n=== 质量门: {os.path.basename(path)} ===")
    for name, lvl, val, note in r["checks"]:
        print(f"  [{ICON[lvl]}] {name:10s} {val:>8s}   ({note})")
    if m:
        print(f"  ---- HR={m['hr']:.1f}  SDNN={m['sdnn_lo']:.0f}ms(±30%)/{m['sdnn_hi']:.0f}ms(±50%)  拍{m['n_beat']}")
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
