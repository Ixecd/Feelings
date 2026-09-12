#!/usr/bin/env python3
"""test_quality_gate.py — quality_gate 的判别力回归（合成信号，不需要硬件）

判据：门必须"放过干净、拦下脏"。用已知属性的合成信号钉死这条。
用法: python3.14 test_quality_gate.py
"""
import os, sys, tempfile
import numpy as np
import quality_gate as qg

FS = 100.0; T = 180.0
t = np.arange(0, T, 1 / FS)
# 带 RSA 调制的脉搏（1.2Hz≈72bpm + 重搏波）
_ph = np.cumsum(2 * np.pi * 1.2 * (1 + 0.04 * np.sin(2 * np.pi * 0.15 * t)) / FS)
PULSE = 1000 * np.sin(_ph) + 300 * np.sin(2 * _ph)
DC = 110000


def _csv(reds, tag):
    ts = 1e9 + t
    p = os.path.join(tempfile.gettempdir(), f"qgtest_{tag}.csv")
    with open(p, "w") as f:
        f.write("t,idx,red,beat,ibi_samples,ibi_ms\n")
        for i, r in enumerate(reds):
            f.write(f"{ts[i]:.3f},{i},{int(r)},0,0,0\n")
    return p


def main():
    rng = np.random.default_rng(1)
    cases = [
        ("干净(σ=10)", DC + PULSE + rng.normal(0, 10, len(t)), "就应 PASS"), 
        ("有呼吸漂移", DC + PULSE + 1500 * np.sin(2 * np.pi * 0.25 * t) + rng.normal(0, 10, len(t)), "就应 PASS"),
        ("重噪(σ=40)", DC + PULSE + rng.normal(0, 40, len(t)), "就应 FAIL"),
        ("漂移淹没", DC + 0.3 * PULSE + 6000 * np.sin(2 * np.pi * 0.2 * t) + rng.normal(0, 40, len(t)), "就应 FAIL"),
    ]
    expect = {"干净(σ=10)": "PASS", "有呼吸漂移": "PASS", "重噪(σ=40)": "FAIL", "漂移淹没": "FAIL"}
    fails = 0
    for tag, reds, why in cases:
        r = qg.gate(*qg.load_csv(_csv(reds, tag.replace(" ", "").replace("=", "").replace("(", "").replace(")", ""))))
        got = r["overall"]; exp = expect[tag]
        ok = got == exp
        fails += (not ok)
        bad = [n for n, l, _, _ in r["checks"] if l != "PASS"]
        print(f"  [{'✓' if ok else '✗'}] {tag:12s} 实得{got:4s} (期望{exp})  {why}  触发:{bad}")
    # 有真实数据就顺便看一眼（不硬断言）
    real = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hrv_log.csv")
    if os.path.exists(real) and os.path.getsize(real) > 1000:
        r = qg.gate(*qg.load_csv(real))
        print(f"  [--] 真实 hrv_log.csv        实得{r['overall']}  (仅供参考)")
    print(f"\n{'全部通过' if not fails else f'{fails} 项未达预期'}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
