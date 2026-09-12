#!/usr/bin/env python3
"""s1_analyze.py — 读 HRV CSV + 条件时间线，逐块算 HR/SDNN，对比

用法: python3.14 s1_analyze.py --hrv hrv_log_xxx.csv --tl hrv_log_xxx.timeline.csv
（时间线由 s1_protocol.py 生成；两者都用墙钟时间，天然对齐）
"""
import argparse
import numpy as np
import quality_gate as qg


def block_stats(ts, reds, t0, t1):
    m = (ts >= t0) & (ts < t1)
    if m.sum() < 200:
        return None
    tt, rr = ts[m], reds[m]
    fs = len(rr) / (tt[-1] - tt[0])
    ib = np.asarray(qg.detect_from_red(rr, fs), float)
    if len(ib) < 5:
        return None
    med = np.median(ib)
    g = ib[(ib >= 0.7 * med) & (ib <= 1.3 * med)]
    if len(g) < 5:
        return None
    return dict(hr=60000.0 / g.mean(), sdnn=float(g.std(ddof=1)), n=len(g), dur=float(tt[-1] - tt[0]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hrv", required=True)
    ap.add_argument("--tl", required=True)
    a = ap.parse_args()
    ts, reds, _ = qg.load_csv(a.hrv)
    rows = [l.strip().split(",") for l in open(a.tl) if l.strip()][1:]
    print(f"{'条件':12s} {'时长s':>6s} {'HR':>7s} {'SDNN':>7s} {'拍':>5s}")
    by = {}
    for r in rows:
        if len(r) < 3:
            continue
        t0, t1, cond = float(r[0]), float(r[1]), r[2]
        st = block_stats(ts, reds, t0, t1)
        if st is None:
            print(f"{cond:12s}   --   (样本不足)")
            continue
        print(f"{cond:12s} {st['dur']:6.0f} {st['hr']:7.1f} {st['sdnn']:7.0f} {st['n']:5d}")
        by.setdefault(cond, []).append(st)
    if len(by) > 1:
        print("\n=== 汇总（各条件均值）===")
        for c, ss in by.items():
            hr = float(np.mean([s['hr'] for s in ss]))
            sd = float(np.mean([s['sdnn'] for s in ss]))
            print(f"  {c:12s} HR={hr:5.1f}  SDNN={sd:4.0f}ms  (n={len(ss)} 块)")


if __name__ == "__main__":
    main()
