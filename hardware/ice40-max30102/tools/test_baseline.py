#!/usr/bin/env python3
"""test_baseline.py — baseline 预测区间的回归（合成数据，无需硬件）

钉死的关键性质（用户定义）：区间 N 小→宽，N 大→收窄并在 ~1.96σ 处稳定（不归零）。
用法: python3.14 test_baseline.py
"""
import os, sys, tempfile, subprocess
import numpy as np
import baseline as B

HERE = os.path.dirname(os.path.abspath(__file__))


def _csv_from_ibi(ibi, tag):
    p = os.path.join(tempfile.gettempdir(), f"bl_{tag}.csv")
    with open(p, "w") as f:
        f.write("t,idx,red,beat,ibi_samples,ibi_ms\n")
        for i, v in enumerate(ibi):
            f.write(f"{1e9+i*0.04:.3f},{i},100000,1,0,{v:.1f}\n")
    return p


def main():
    fails = 0

    # 1. 固定 σ 下：区间随 N 单调收窄，并收敛到 ~1.96σ
    sd = 8.0
    traj = B._trajectory(sd)
    halves = [h for _, h in traj]
    mono = all(halves[i] > halves[i + 1] for i in range(len(halves) - 1))
    conv = abs(halves[-1] - 1.96 * sd) / (1.96 * sd) < 0.05
    print(f"  [{'✓' if mono else '✗'}] 固定σ=8: 单调收窄 {halves[0]:.0f}→{halves[-1]:.0f} ({traj})")
    print(f"  [{'✓' if conv else '✗'}] 收敛到 1.96σ={1.96*sd:.1f} (实得 {halves[-1]:.1f})")
    fails += (not mono) + (not conv)

    # 2. N=1 → 区间未成形（inf），不能假装有基线
    one = B._agg([50.0])
    ok1 = one["half"] == float("inf")
    print(f"  [{'✓' if ok1 else '✗'}] N=1 → half=inf（未成形）")
    fails += (not ok1)

    # 3. 大 N → 半宽 ≈ 1.96·σ（不是 mean±1σ）
    rng = np.random.default_rng(3); pool = rng.normal(55, 8, 300)
    a = B._agg(pool)
    ok3 = abs(a["half"] - 1.96 * a["sd"]) / (1.96 * a["sd"]) < 0.03
    print(f"  [{'✓' if ok3 else '✗'}] 大N: half={a['half']:.1f} ≈ 1.96σ={1.96*a['sd']:.1f}")
    fails += (not ok3)

    # 4. 端到端：build 3 次 → check 一个区间内 + 一个明显出界
    rng = np.random.default_rng(5)
    base_csv = [_csv_from_ibi(rng.normal(800, 40, 700), f"s{i}") for i in range(3)]
    bj = os.path.join(tempfile.gettempdir(), "bl_base.json")
    r = subprocess.run([sys.executable, os.path.join(HERE, "baseline.py"), "build"] + base_csv + ["-o", bj],
                       capture_output=True, text=True)
    ok4 = r.returncode == 0 and os.path.exists(bj)
    print(f"  [{'✓' if ok4 else '✗'}] build 3 次会话 → {os.path.basename(bj)}")
    print("      " + "  ".join(l.strip() for l in r.stdout.splitlines() if "±" in l or "状态" in l))
    fails += (not ok4)

    inb = _csv_from_ibi(rng.normal(800, 40, 700), "in")
    out = _csv_from_ibi(rng.normal(800, 130, 700), "out")
    r_in = subprocess.run([sys.executable, os.path.join(HERE, "baseline.py"), "check", bj, inb],
                          capture_output=True, text=True)
    r_out = subprocess.run([sys.executable, os.path.join(HERE, "baseline.py"), "check", bj, out],
                           capture_output=True, text=True)
    vin = "正常" in r_in.stdout
    vout = "超出区间" in r_out.stdout
    print(f"  [{'✓' if vin else '✗'}] check 区间内会话 → 判'正常'")
    print(f"  [{'✓' if vout else '✗'}] check 明显离群会话 → 判'超出区间'")
    fails += (not vin) + (not vout)

    print(f"\n{'全部通过' if not fails else f'{fails} 项未达预期'}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
