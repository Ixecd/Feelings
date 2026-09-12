#!/usr/bin/env python3
"""s1_protocol.py — S1 开环实验驱动：定时切条件（放/停音频 + 提示任务）+ 写时间线

它会：起 hrv_monitor 采集 → 按 seq 依次执行每个条件块（放/停音频、打印提示）→
      写一份「条件时间线」CSV（t_start,t_end,condition），供 s1_analyze 对齐。

用法：
  python3.14 s1_protocol.py --audio song.mp3 --seq "music,silence,music,silence" --block 120
  # 最小版：只比 音乐 vs 静音（推荐先跑这个）
  # 加注意：--seq "music,music_task,task,music,music_task,task"

条件（内置）：
  music        放音频，专注听（注意在音乐）
  silence      不放音频，静坐
  music_task   放音频 + 心算（音乐当背景）
  task         不放音频 + 心算（减掉"心算"本身的效应）
"""
import argparse, subprocess, sys, time, os

COND = {
    "music":      ("专注听音乐（跟着听，别想别的）",          True),
    "silence":    ("静坐（不看手机、不说话）",                False),
    "music_task": ("心算：从 100 每次减 7，出声数（音乐当背景）", True),
    "task":       ("心算：从 100 每次减 7，出声数（无音乐）",    False),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--audio", default=None, help="音频文件（music 条件要它）")
    ap.add_argument("--seq", default="music,silence,music,silence")
    ap.add_argument("--block", type=float, default=120.0, help="每块秒数")
    ap.add_argument("--device", default="/dev/cu.usbserial-0001")
    ap.add_argument("--hrv-out", default=time.strftime("hrv_log_%Y%m%d-%H%M%S.csv"))
    ap.add_argument("--tl-out", default=None)
    a = ap.parse_args()
    tl = a.tl_out or (os.path.splitext(a.hrv_out)[0] + ".timeline.csv")
    seq = [s.strip() for s in a.seq.split(",") if s.strip()]
    for c in seq:
        if c not in COND:
            print(f"未知条件 {c}；可选：{list(COND)}"); return
    total = a.block * len(seq) + 6

    here = os.path.dirname(os.path.abspath(__file__))
    print(f"起采集: hrv_monitor {a.device} {total:.0f} 100 {a.hrv_out}")
    hm = subprocess.Popen([sys.executable, os.path.join(here, "hrv_monitor.py"),
                           a.device, str(total), "100", a.hrv_out])
    time.sleep(3)                                   # 让采集先起来
    audio = None
    with open(tl, "w") as f:
        f.write("t_start,t_end,condition\n")
        for cond in seq:
            prompt, want = COND[cond]
            if want and a.audio:
                if audio is None:
                    audio = subprocess.Popen(["afplay", a.audio])
            else:
                if audio is not None:
                    audio.terminate(); audio = None
            t0 = time.time()
            print(f"\n>>> [{cond}] {prompt}  ({a.block:.0f}s)")
            time.sleep(a.block)
            t1 = time.time()
            f.write(f"{t0:.3f},{t1:.3f},{cond}\n"); f.flush()
    if audio is not None:
        audio.terminate()
    hm.wait()
    print(f"\n已存 HRV {a.hrv_out}\n已存时间线 {tl}")
    print(f"分析: python3.14 s1_analyze.py --hrv {a.hrv_out} --tl {tl}")


if __name__ == "__main__":
    main()
