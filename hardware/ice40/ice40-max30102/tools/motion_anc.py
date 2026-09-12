#!/usr/bin/env python3
"""motion_anc.py — 用加速度当参考，对 PPG 做自适应对消(NLMS)去运动伪迹

原理（Widrow 自适应噪声对消）：
    PPG 里 = 脉搏(想留) + 运动伪迹(想删)。运动伪迹与加速度同源、相关；
    脉搏与加速度不相关。用 accel 当"参考"，LMS 自适应估计伪迹分量 ŷ，
    从 PPG 里减掉 → 剩下的就是脉搏。无需知道伪迹长什么样，只要它有相关参考。

用法：
  python3.14 motion_anc.py --selftest          # 合成信号自测（pulse+伪迹 → 看恢复）
  python3.14 motion_anc.py hrv_log_xxx.csv     # 对真实 9 列会话做 ANC，比前后 HR/SDNN
"""
import sys, os, math
import numpy as np
import quality_gate as qg

ORDER = 48      # 滤波器阶数（@100Hz → 覆盖 ~0.5s 的延迟/混响）
MU    = 0.05    # NLMS 步长（归一化后 0<mu<2 稳定；0.05 实测收敛且不过冲——0.5 会抖、0.01 太慢）


def nlms_anc(ppg, ref, order=ORDER, mu=MU, eps=1e-6, gate=None):
    """ref: (N,K) 参考通道；gate: (N,) bool——**只在"有运动"(参考有能量)时更新权重**。
    静止时参考≈0，NLMS 归一化分母趋零 → 权重发散 → 会把脉搏也消掉（实测静止会话被搞坏）。"""
    n = len(ppg); k = ref.shape[1]
    w = np.zeros((order, k)); buf = np.zeros((order, k)); out = np.empty(n)
    for i in range(n):
        buf[1:] = buf[:-1]; buf[0] = ref[i]
        e = ppg[i] - float(np.sum(w * buf))
        if gate is None or gate[i]:
            w += (mu * e / (float(np.sum(buf * buf)) + eps)) * buf
        out[i] = e
    return out


def motion_gate(acc, g=0.05):
    """参考是否"在动"：accel 向量相对会话均值的偏离 > g·1g（0.05g=819）。"""
    ref = acc - acc.mean(axis=0)
    return np.linalg.norm(ref, axis=1) > g * 16384.0


def load9(path):
    ts, ppg, acc = [], [], []
    with open(path) as f:
        f.readline()
        for ln in f:
            p = ln.split(",")
            if len(p) >= 9:
                try:
                    ts.append(float(p[0])); ppg.append(float(p[2]))
                    acc.append((float(p[6]), float(p[7]), float(p[8])))
                except ValueError:
                    pass
    return np.array(ts), np.array(ppg, float), np.array(acc, float)


def beats(ppg, ts):
    fs = len(ppg) / (ts[-1] - ts[0])
    ib = np.asarray(qg.detect_from_red(np.asarray(ppg, float), fs), float)
    if len(ib) < 3:
        return None
    med = np.median(ib); g = ib[(ib >= 0.7 * med) & (ib <= 1.3 * med)]
    return dict(hr=(60000.0 / g.mean() if len(g) else float('nan')),
                sdnn=(float(g.std(ddof=1)) if len(g) > 2 else 0.0), n=len(ib))


def bandpow(x, fs, lo, hi):
    x = x - x.mean(); P = np.abs(np.fft.rfft(x * np.hanning(len(x)))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / fs)
    m = (f >= lo) & (f < hi)
    return float(P[m].sum())


def selftest():
    fs = 100.0; T = 180.0; t = np.arange(0, T, 1 / fs); rng = np.random.default_rng(0)
    # 真脉搏：~70bpm，带 RSA（SDNN 目标 ~40ms）
    rate = (70 / 60.0) * (1 + 0.05 * np.sin(2 * np.pi * 0.25 * t))
    ph = np.cumsum(2 * np.pi * rate / fs)
    pulse = 1000 * np.sin(ph) + 300 * np.sin(2 * ph)
    # 运动伪迹：1.5Hz，与 accel 同源
    mo = 4000 * np.sin(2 * np.pi * 1.5 * t)
    acc = np.column_stack([mo, 0.5 * mo, np.full(len(t), 16384.0)])
    ppg_raw = 110000 + pulse + mo + rng.normal(0, 30, len(t))
    ref = acc - acc.mean(axis=0)                     # 参考去均值
    cleaned = nlms_anc(ppg_raw - ppg_raw.mean(), ref, gate=motion_gate(acc)) + ppg_raw.mean()
    ts = 1e9 + t
    b_true = beats(110000 + pulse, ts)               # 只有脉搏（理想）
    b_raw = beats(ppg_raw, ts)                        # 原始（脉搏+伪迹）
    b_cln = beats(cleaned, ts)                        # ANC 后
    print("=== ANC 自测（脉搏 70bpm + 1.5Hz 运动伪迹）===")
    for name, b in (("理想(只脉搏)", b_true), ("原始(有伪迹)", b_raw), ("ANC后", b_cln)):
        print(f"  {name:14s} HR={b['hr']:6.1f}  SDNN={b['sdnn']:6.1f}ms  拍={b['n']}")
    ap0 = bandpow(ppg_raw, fs, 1.0, 2.0); ap1 = bandpow(cleaned, fs, 1.0, 2.0)
    print(f"  伪迹带(1.0-2.0Hz)功率: 原始={ap0:.3e}  ANC后={ap1:.3e}  (降 {100*(1-ap1/ap0):.1f}%)")
    ok = (b_cln and abs(b_cln['hr'] - b_true['hr']) < 3
          and abs(b_cln['sdnn'] - b_true['sdnn']) < 15 and ap1 < ap0 * 0.1)
    print(f"  → {'✓ ANC：伪迹压下去、HR/SDNN 回到接近理想' if ok else '✗ 未达预期'}")
    return 0 if ok else 1


def _sev(g):
    """门结果 → (overall 严重度, 各检查严重度和)，越小越好。"""
    order = {"N/A": -1, "PASS": 0, "WARN": 1, "FAIL": 2}
    return (order[g["overall"]], sum(order[c[1]] for c in g["checks"]))


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__); return
    if a[0] == "--selftest":
        sys.exit(selftest())
    path = a[0]
    if path.endswith(".meta.json"):          # 顺手：传了 meta 就自动切到同名 csv
        path = path[:-len(".meta.json")] + ".csv"
        print(f"(检测到 meta，改用 {os.path.basename(path)})")
    ts, ppg, acc = load9(path)
    if len(ppg) < 200 or acc is None or len(acc) != len(ppg):
        print("需要 9 列 CSV（含 ax,ay,az）；样本不足或没有 accel 列"); return

    raw = qg.gate(ts, ppg, acc)
    print(f"=== ANC: {os.path.basename(path)} ===")
    print(f"  raw 门: {raw['overall']}")
    # 触发①：raw 已 PASS → 数据本来就干净，不修（避免把干净数据搞坏）
    if raw["overall"] == "PASS":
        print("  raw 已是 PASS —— 跳过 ANC（无需修）"); return
    # 触发②：accel 无显著运动 → 不是运动问题，ANC 帮不上
    ref = acc - acc.mean(axis=0)
    gate = motion_gate(acc)
    if gate.mean() < 0.05:
        print(f"  运动门 {gate.mean()*100:.0f}% —— raw 非 PASS 但无显著运动，跳过 ANC"); return

    cleaned = nlms_anc(ppg - ppg.mean(), ref, gate=gate) + ppg.mean()
    cl = qg.gate(ts, cleaned, acc)
    b0, b1 = beats(ppg, ts), beats(cleaned, ts)
    print(f"  运动门 {gate.mean()*100:.0f}%（只在这些样本上自适应权重）")
    print(f"  原始   HR={b0['hr']:.1f}  SDNN={b0['sdnn']:.0f}ms  拍={b0['n']}   门={raw['overall']}(分级和 {_sev(raw)[1]})")
    print(f"  ANC后  HR={b1['hr']:.1f}  SDNN={b1['sdnn']:.0f}ms  拍={b1['n']}   门={cl['overall']}(分级和 {_sev(cl)[1]})")
    fs = len(ppg) / (ts[-1] - ts[0])
    print(f"  伪迹带(1.0-2.0Hz): 原始={bandpow(ppg,fs,1.0,2.0):.3e}  ANC后={bandpow(cleaned,fs,1.0,2.0):.3e}")
    dr = {n: l for n, l, _, _ in raw["checks"]}
    dc = {n: l for n, l, _, _ in cl["checks"]}
    chg = [f"{n}:{dr[n]}→{dc[n]}" for n in dr if dr[n] != dc[n]]
    print("  门变化: " + ("  ".join(chg) if chg else "无"))
    # 触发③：ANC 后用门复评，更差就丢弃
    print("  → ANC 后更好，采纳" if _sev(cl) < _sev(raw) else "  → ANC 后不更好，丢弃（保持 raw）")


if __name__ == "__main__":
    main()
