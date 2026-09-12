#!/usr/bin/env python3
"""test_baseline.py — baseline 预测区间的回归（合成数据，无需硬件）

2026-09-12 升级：load_beats 改成从 red 重新检测（不信 CSV 存的 beat 列），
所以测试必须造**真实脉搏波形**，不能再写常数 red + 假 ibi_ms。

钉死的关键性质（用户定义）：区间 N 小→宽，N 大→收窄并在 ~1.96σ 处稳定（不归零）。
用法: python3.14 test_baseline.py
"""
import os, sys, tempfile, subprocess
import numpy as np
import baseline as B

HERE = os.path.dirname(os.path.abspath(__file__))
FS = 100.0


def _red_from_ibi(ibi_ms, seed=0):
    """由 IBI 序列造脉搏波形：每拍相位推进 2π，含重搏波 + 噪声"""
    rng = np.random.default_rng(seed)
    ph = []
    for ib in ibi_ms:
        k = max(2, int(round(ib / 1000.0 * FS)))
        ph.extend(2 * np.pi * np.arange(k) / k)
    ph = np.array(ph)
    red = 110000 + 1000 * np.sin(ph) + 300 * np.sin(2 * ph) + rng.normal(0, 30, len(ph))
    return red


def _csv(red, tag):
    p = os.path.join(tempfile.gettempdir(), f"bl_{tag}.csv")
    with open(p, "w") as f:
        f.write("t,idx,red,beat,ibi_samples,ibi_ms\n")
        for i, v in enumerate(red):
            f.write(f"{1e9 + i / FS:.3f},{i},{int(v)},0,0,0\n")
    return p


def main():
    fails = 0

    # 1. 固定 σ 下：区间随 N 单调收窄，并收敛到 ~1.96σ
    sd = 8.0
    traj = B._trajectory(sd)
    halves = [h for _, h in traj]
    mono = all(halves[i] > halves[i + 1] for i in range(len(halves) - 1))
    conv = abs(halves[-1] - 1.96 * sd) / (1.96 * sd) < 0.05
    print(f"  [{'✓' if mono else '✗'}] 固定σ=8: 单调收窄 {halves[0]:.0f}→{halves[-1]:.0f}")
    print(f"  [{'✓' if conv else '✗'}] 收敛到 1.96σ={1.96*sd:.1f} (实得 {halves[-1]:.1f})")
    fails += (not mono) + (not conv)

    # 2. N=1 → 区间未成形（inf）
    one = B._agg([50.0])
    ok1 = one["half"] == float("inf")
    print(f"  [{'✓' if ok1 else '✗'}] N=1 → half=inf（未成形）")
    fails += (not ok1)

    # 3. 大 N → 半宽 ≈ 1.96·σ
    rng = np.random.default_rng(3); pool = rng.normal(55, 8, 300)
    a = B._agg(pool)
    ok3 = abs(a["half"] - 1.96 * a["sd"]) / (1.96 * a["sd"]) < 0.03
    print(f"  [{'✓' if ok3 else '✗'}] 大N: half={a['half']:.1f} ≈ 1.96σ={1.96*a['sd']:.1f}")
    fails += (not ok3)

    # 4. 检测回路：从 red 能还原出接近的 HR（证明 load_beats 走的是 red）
    ibi = rng.normal(800, 40, 500)
    p = _csv(_red_from_ibi(ibi, 7), "det")
    st = B.session_stats(B.load_beats(p))
    ok_det = st is not None and abs(st["hr"] - 60000 / np.mean(ibi)) < 5
    print(f"  [{'✓' if ok_det else '✗'}] 从 red 重检测: HR={st['hr']:.1f} (注入 {60000/np.mean(ibi):.1f})")
    fails += (not ok_det)

    # 5. 端到端：build 3 次 → check 区间内 + 明显离界
    base_csv = [_csv(_red_from_ibi(rng.normal(800, 40, 700), i), f"s{i}") for i in range(3)]
    bj = os.path.join(tempfile.gettempdir(), "bl_base.json")
    r = subprocess.run([sys.executable, os.path.join(HERE, "baseline.py"), "build"] + base_csv + ["-o", bj],
                       capture_output=True, text=True)
    ok5 = r.returncode == 0 and os.path.exists(bj)
    print(f"  [{'✓' if ok5 else '✗'}] build 3 会话")
    print("      " + "  ".join(l.strip() for l in r.stdout.splitlines() if "±" in l or "状态" in l))
    fails += (not ok5)

    inb = _csv(_red_from_ibi(rng.normal(800, 40, 700), 9), "in")
    out = _csv(_red_from_ibi(rng.normal(800, 130, 700), 9), "out")
    r_in = subprocess.run([sys.executable, os.path.join(HERE, "baseline.py"), "check", bj, inb],
                          capture_output=True, text=True)
    r_out = subprocess.run([sys.executable, os.path.join(HERE, "baseline.py"), "check", bj, out],
                           capture_output=True, text=True)
    vin = "正常" in r_in.stdout
    vout = "超出区间" in r_out.stdout
    print(f"  [{'✓' if vin else '✗'}] check 区间内 → 判'正常'")
    print(f"  [{'✓' if vout else '✗'}] check 明显离群 → 判'超出区间'")
    fails += (not vin) + (not vout)

    print(f"\n{'全部通过' if not fails else f'{fails} 项未达预期'}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
