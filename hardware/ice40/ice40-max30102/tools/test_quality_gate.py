#!/usr/bin/env python3
"""test_quality_gate.py — quality_gate 的判别力回归（合成信号，不需要硬件）

判据（按"数据能不能进基线"的语义，不是死记某个评级）：
  · 干净数据 → 必须 PASS
  · HR 自然漂移 → **不得判 FAIL**（回归 2026-09-12 的 bug：旧"自相关一致"指标
    拿全窗自相关当参考，而 HR 漂移时全窗自相关失去内部峰 → 误杀好数据）
  · 噪声大但脉搏清晰 → 至少 WARN（不能直接 PASS 蒙混过关）
  · 漂移淹没脉搏 → 必须 FAIL（真坏数据要拦下）

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
    # HR 从 60 漂到 90 bpm —— 模拟运动中/自然波动的会话
    _rate = np.linspace(1.0, 1.5, len(t))
    _phd = np.cumsum(2 * np.pi * _rate / FS)
    DRIFT = DC + 1000 * np.sin(_phd) + 300 * np.sin(2 * _phd) + rng.normal(0, 10, len(t))

    specs = [
        ("干净", DC + PULSE + rng.normal(0, 10, len(t)), lambda v: v == "PASS", "必须 PASS"),
        ("呼吸漂移", DC + PULSE + 1500 * np.sin(2 * np.pi * 0.25 * t) + rng.normal(0, 10, len(t)),
         lambda v: v == "PASS", "必须 PASS"),
        ("HR漂移", DRIFT, lambda v: v != "FAIL", "HR 变化不是错误 → 不得 FAIL"),
        ("重噪s40", DC + PULSE + rng.normal(0, 40, len(t)), lambda v: v in ("WARN", "FAIL"), "至少 WARN"),
        ("漂移淹没", DC + 0.3 * PULSE + 6000 * np.sin(2 * np.pi * 0.2 * t) + rng.normal(0, 40, len(t)),
         lambda v: v == "FAIL", "真坏数据必须 FAIL"),
    ]
    fails = 0
    for tag, reds, ok_fn, why in specs:
        r = qg.gate(*qg.load_csv(_csv(reds, tag)))
        got = r["overall"]; ok = ok_fn(got)
        fails += (not ok)
        bad = [n for n, l, _, _ in r["checks"] if l != "PASS"]
        print(f"  [{'✓' if ok else '✗'}] {tag:8s} 实得{got:4s}  ({why})  触发:{bad}")
    # 有真实数据就顺便看一眼（不硬断言）
    real = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../hrv_log.csv")
    if os.path.exists(real) and os.path.getsize(real) > 1000:
        r = qg.gate(*qg.load_csv(real))
        print(f"  [--] 真实 ../hrv_log.csv  实得{r['overall']}  (仅供参考)")
    print(f"\n{'全部通过' if not fails else f'{fails} 项未达预期'}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
