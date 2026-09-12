#!/usr/bin/env python3
"""baseline.py — 跨会话聚合：把多次 hrv_monitor.py 的 hrv_log.csv 汇总成个体基线区间

定位：S0（建个体基线）缺的那一块。hrv_monitor.py 出单会话数据；本脚本跨会话聚合。

口径（必须与 hrv_monitor.py 一致，否则数不可比）：
  · 只用 beat==1 且 ibi_ms>0 的拍
  · 中位数 0.7~1.3 清洗异常（同 hrv_monitor._clean）
  · SDNN 用 5min 窗（临床标准，同 hrv_monitor 的 5min SDNN）——不是整段标准差
  · 不用 RMSSD 作判据（FORGET.md：指尖 PPG 峰位 ±100ms 抖 → RMSSD 虚高）

用法（用 python3.14——系统 python3 是 3.9、无 numpy）:
  python3.14 baseline.py build  hrv_log_d1a.csv hrv_log_d1b.csv ...  [-o baseline.json]
  python3.14 baseline.py check  baseline.json  new_session.csv
"""
import sys, os, json
import numpy as np

WIN_S = 300.0   # SDNN 窗（5min），对齐 hrv_monitor


def load_beats(path):
    """从 hrv_log.csv 取拍间期(ms)。列: t,idx,red,beat,ibi_samples,ibi_ms"""
    ibi = []
    with open(path) as f:
        for ln in f:
            ln = ln.strip()
            if not ln or ln.startswith("t,"):
                continue
            p = ln.split(",")
            if len(p) < 6:
                continue
            try:
                beat = int(p[3]); ib = float(p[5])
            except ValueError:
                continue
            if beat == 1 and ib > 0:
                ibi.append(ib)
    return ibi


def clean(a):
    """中位数 0.7~1.3 剔异常（同 hrv_monitor._clean）"""
    a = np.asarray(a, float)
    if len(a) < 3:
        return a
    med = float(np.median(a))
    return a[(a >= 0.70 * med) & (a <= 1.30 * med)]


def sdnn_5min(g):
    """按拍时刻切 5min 窗，逐窗 SDNN，取均值。不足一窗则整段 SDNN。"""
    t = np.cumsum(g) / 1000.0            # 拍时刻(s)，从 0 起
    if t[-1] <= WIN_S:
        return float(g.std(ddof=1)), 1
    sds, start = [], 0.0
    while start + WIN_S <= t[-1] + 1e-9:
        m = (t >= start) & (t < start + WIN_S)
        if m.sum() >= 3:
            sds.append(float(g[m].std(ddof=1)))
        start += WIN_S
    return (float(np.mean(sds)), len(sds)) if sds else (float(g.std(ddof=1)), 1)


def session_stats(ibi):
    g = clean(ibi)
    if len(g) < 3:
        return None
    d = np.diff(g)
    rmssd = float(np.sqrt((d * d).mean())) if len(d) else float("nan")
    sdnn, nwin = sdnn_5min(g)
    return dict(
        n_beat=int(len(g)), n_raw=int(len(ibi)),
        dur_s=float(g.sum() / 1000.0), n_win=nwin,
        hr=float(60000.0 / g.mean()),
        sdnn=sdnn,
        rmssd=rmssd,   # 仅记录参照，不作判据
    )


def _agg(vals):
    v = np.asarray(vals, float)
    m = float(v.mean())
    s = float(v.std(ddof=1)) if len(v) > 1 else 0.0
    return dict(mean=m, sd=s, lo=m - s, hi=m + s)


def build(paths):
    per = []
    for p in paths:
        st = session_stats(load_beats(p))
        if st is None:
            print(f"  跳过 {os.path.basename(p)}：有效拍不足")
            continue
        st["file"] = os.path.basename(p)
        per.append(st)
    if not per:
        return None
    if len(per) < 5:
        print(f"\n⚠ 只有 {len(per)} 次会话——基线需要 ≥5（S0 建议：≥5 天 × 每天 2 次 = ≥10 次）")
    return dict(
        n_sessions=len(per),
        hr=_agg([s["hr"] for s in per]),
        sdnn=_agg([s["sdnn"] for s in per]),
        sessions=per,
    )


def check(base, path):
    st = session_stats(load_beats(path))
    if st is None:
        print("有效拍不足，无法判定")
        return

    def judge(v, d):
        m, s = d["mean"], d["sd"]
        if s == 0:
            return f"{v:.1f} (基线 {m:.1f}±0，σ=0——基线未成形)"
        z = (v - m) / s
        tag = "在 ±1σ 内（正常）" if abs(z) <= 1 else ("超出 ±1σ" if abs(z) <= 2 else "超出 ±2σ ⚠")
        return f"{v:.1f}  基线 {m:.1f}±{s:.1f}  z={z:+.2f}  →  {tag}"

    print(f"会话 {os.path.basename(path)}: {st['n_beat']} 有效拍 / {st['dur_s']:.0f}s")
    print(f"  HR   : {judge(st['hr'], base['hr'])}")
    print(f"  SDNN : {judge(st['sdnn'], base['sdnn'])}")
    print(f"  (RMSSD={st['rmssd']:.0f}ms 仅参照——FORGET.md 判定指尖 PPG 的 RMSSD 不可信)")


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    if a[0] == "build":
        rest, out = a[1:], "baseline.json"
        if "-o" in rest:
            k = rest.index("-o")
            out, rest = rest[k + 1], rest[:k] + rest[k + 2:]
        base = build(rest)
        if base is None:
            print("无有效会话")
            return
        with open(out, "w") as f:
            json.dump(base, f, ensure_ascii=False, indent=2)
        print(f"\n=== 个体基线（{base['n_sessions']} 次会话）===")
        print(f"  HR  : {base['hr']['mean']:.1f} ± {base['hr']['sd']:.1f} bpm   "
              f"区间 {base['hr']['lo']:.1f}~{base['hr']['hi']:.1f}")
        print(f"  SDNN: {base['sdnn']['mean']:.0f} ± {base['sdnn']['sd']:.0f} ms    "
              f"区间 {base['sdnn']['lo']:.0f}~{base['sdnn']['hi']:.0f}")
        print(f"  → 已存 {out}")
    elif a[0] == "check":
        check(json.load(open(a[1])), a[2])
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
