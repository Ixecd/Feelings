#!/usr/bin/env python3
"""baseline.py — 跨会话聚合：把多次 hrv_monitor.py 的 hrv_log.csv 汇总成个体基线区间

定位：S0（建个体基线）缺的那一块。hrv_monitor.py 出单会话数据；本脚本跨会话聚合。

口径（必须与 hrv_monitor.py 一致，否则数不可比）：
  · 只用 beat==1 且 ibi_ms>0 的拍
  · 中位数 0.7~1.3 清洗异常（同 hrv_monitor._clean）
  · SDNN 用 5min 窗（临床标准）——不是整段标准差
  · 不用 RMSSD 作判据（FORGET.md：指尖 PPG 峰位 ±100ms 抖 → RMSSD 虚高）

基线区间的行为（关键设计）：用 95% 预测区间，不是 mean±1σ——
      half = t(0.975, N-1) · σ · √(1 + 1/N)
  N 小 → t 大 + σ 不可靠 → 区间宽；N 大 → t→1.96、σ 收敛 → 区间收窄后**基本不变**。
  这是"穿戴设备有误差、基线先宽后窄最后稳定"的正确数学形状（不会收成零）。
  这也天然防小样本假警报：3 次就报"超出"是过度自信。

用法（用 python3.14——系统 python3 是 3.9、无 numpy）:
  python3.14 baseline.py build  hrv_log_d1a.csv hrv_log_d1b.csv ...  [-o baseline.json]
  python3.14 baseline.py check  baseline.json  new_session.csv
"""
import sys, os, json, math
import numpy as np
import quality_gate   # 复用同一套谷底检测，保证 baseline 与质量门口径一致

WIN_S = 300.0   # SDNN 窗（5min），对齐 hrv_monitor
CONVERGE_N = 6   # 认为"够用"的会话数下限（2026-09-12 定为 6：受控静坐基线，6 次足够）

# t 分布 0.975 分位（df=N-1），小样本用查表，大样本趋近 1.96
_T95 = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306,
        9: 2.262, 10: 2.228, 11: 2.201, 12: 2.179, 13: 2.160, 14: 2.145, 15: 2.131,
        16: 2.120, 17: 2.110, 18: 2.101, 19: 2.093, 20: 2.086, 21: 2.080, 22: 2.074,
        23: 2.069, 24: 2.064, 25: 2.060, 26: 2.056, 27: 2.052, 28: 2.048, 29: 2.045, 30: 2.042}


def t95(df):
    if df <= 0:
        return float("inf")
    if df in _T95:
        return _T95[df]
    if df <= 30:
        return _T95[30]
    return 2.042 - (2.042 - 1.960) * min(1.0, (df - 30) / 90.0)   # 30→120 线性逼近到 1.96


def load_beats(path):
    """读 hrv_log.csv 的原始 red 序列，用当前检测器重新检测拍间期(ms)。

    纪律：**不读 CSV 里存的 beat/ibi 列**——那是采集时哪个版本的检测器写的就是哪个，
    跨检测器版本的会话会因此不可比（SDNN 差异来自代码而非生理）。
    必须从 red 重来，与 quality_gate 同一口径。"""
    ts, reds = [], []
    with open(path) as f:
        for ln in f:
            ln = ln.strip()
            if not ln or ln.startswith("t,"):
                continue
            p = ln.split(",")
            if len(p) < 3:
                continue
            try:
                ts.append(float(p[0])); reds.append(float(p[2]))
            except ValueError:
                continue
    if len(reds) < 200 or ts[-1] <= ts[0]:
        return []
    fs = len(reds) / (ts[-1] - ts[0])
    return list(quality_gate.detect_from_red(np.asarray(reds, float), fs))


def clean(a):
    """中位数 0.7~1.3 剔异常（同 hrv_monitor._clean）"""
    a = np.asarray(a, float)
    if len(a) < 3:
        return a
    med = float(np.median(a))
    return a[(a >= 0.70 * med) & (a <= 1.30 * med)]


def sdnn_5min(g):
    """按拍时刻切 5min 窗，逐窗 SDNN，取均值。不足一窗则整段 SDNN。"""
    t = np.cumsum(g) / 1000.0
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
    """95% 预测区间（新单次观测）：half = t(.975,N-1)·σ·√(1+1/N)"""
    v = np.asarray(vals, float)
    n = len(v)
    m = float(v.mean())
    s = float(v.std(ddof=1)) if n > 1 else 0.0
    half = (t95(n - 1) * s * math.sqrt(1.0 + 1.0 / n)) if n > 1 else float("inf")
    return dict(n=n, mean=m, sd=s, half=half, lo=m - half, hi=m + half)


def _trajectory(sd, ns=(5, 10, 30, 60)):
    """若 σ 保持不变，攒到 N 次时区间半宽会收窄到多少（N 小→大）"""
    return [(n, t95(n - 1) * sd * math.sqrt(1.0 + 1.0 / n)) for n in ns]


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
    if len(per) < CONVERGE_N:
        print(f"\n⚠ 只有 {len(per)} 次会话——区间会很宽（正常，先宽后窄）。S0 建议 ≥{CONVERGE_N} 次")
    agg_hr = _agg([s["hr"] for s in per])
    agg_sd = _agg([s["sdnn"] for s in per])
    return dict(n_sessions=len(per), converge_n=CONVERGE_N, hr=agg_hr, sdnn=agg_sd, sessions=per)


def _fmt(d, unit):
    if math.isinf(d["half"]):
        return f"{d['mean']:.1f} {unit}  (只有 1 次会话，区间未成形)"
    return (f"{d['mean']:.1f} ± {d['half']:.1f} {unit}   [{d['lo']:.1f} ~ {d['hi']:.1f}]   "
            f"(σ={d['sd']:.1f}, N={d['n']})")


def check(base, path):
    st = session_stats(load_beats(path))
    if st is None:
        print("有效拍不足，无法判定")
        return

    def judge(v, d):
        if math.isinf(d["half"]):
            return f"{v:.1f}  (基线未成形，只有 1 次会话)"
        z = (v - d["mean"]) / (d["sd"] if d["sd"] else 1e-9)
        inb = d["lo"] <= v <= d["hi"]
        tag = "在基线区间内（正常）" if inb else "**超出区间** ⚠（可疑，但 N 小先别下结论）"
        return (f"{v:.1f}   基线 {d['mean']:.1f}±{d['half']:.1f} [{d['lo']:.1f}~{d['hi']:.1f}]"
                f"   z≈{z:+.2f}   →  {tag}")

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
        n = base["n_sessions"]
        print(f"\n=== 个体基线（{n} 次会话，95% 预测区间）===")
        print(f"  HR  : {_fmt(base['hr'], 'bpm')}")
        print(f"  SDNN: {_fmt(base['sdnn'], 'ms')}")
        print(f"  状态: {'已收敛(N≥'+str(base['converge_n'])+')' if n >= base['converge_n'] else '暂定(N<'+str(base['converge_n'])+')——区间会随后续数据收窄'}")
        print("  收窄轨迹（若 σ 不变）:  " +
              "  ".join(f"N={nn}→±{hh:.0f}" for nn, hh in _trajectory(base["sdnn"]["sd"])))
        print(f"  → 已存 {out}")
    elif a[0] == "check":
        check(json.load(open(a[1])), a[2])
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
