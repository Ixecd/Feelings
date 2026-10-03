# ecp5-i5 —— 索引（先看这里）

> 目的：这个目录里文稿不止一份，先看这张表知道**从哪份开始、哪份已过时**。
> 更新：2026-10-03

---

## 当前有效（要看就看这两份）

| 文稿 | 是什么 | 什么时候看 |
|---|---|---|
| **`tvns-stim-topology-v1-2026-10-03.md`** | ★ **拓扑设计 v1.2**（T1：离散 H 桥 + 低边恒流 sink；含完整图/保护/待锁参数/免责） | 想知道"电路为什么这么设计" |
| **`tvns-stim-t1-build-manual-2026-10-03.md`** | ★ **接线手册 v1.1**（Step 0~4，全引脚，判据，故障对照） | 动手搭建时对着做 |

> 一句话：**设计看 topology，动手看 build-manual。** 两份都是 v1 系（T1）。

---

## 半过时（安全模型仍有效，器件/接线部分已过时）

| 文稿 | 状态 |
|---|---|
| `tvns-stim-build-plan-2026-09-20.md` | **部分过时**：Phase A–D / 接线表 / 器件（ISO7721/L293D/5V）已过时；**但里面的"安全层模型 Layer 0–5 + 三条公理 + 电流三层上限"仍然有效**，是系统的安全框架 |

---

## 已删除（历史，需要时从 git 捞）

| 文稿 | 为什么删 |
|---|---|
| ~~`tvns-stim-circuit-v0-2026-09-13.md`~~ | v0 电路（LM334 + L293D）已被 topology v1 取代 |
| ~~`tvns-stim-breadboard-manual-2026-09-20.md`~~ | 旧施工手册（LM334/L293D/ISO7721）已被 T1 build-manual 取代 |

捞法：`git log --oneline -- <旧路径>` 找到 commit，再 `git show <commit>:<路径>`。

---

## 其它（另一主题）

| 文稿 | 是什么 |
|---|---|
| `ecp5-i5-bringup-2026-09-09.md` | i5 (ECP5) 板级 bringup（工具链/烧录），与刺激链无直接关系 |
| `stim_pulse/` | 双相脉冲 RTL（`ecp5_stim_pulse.v`，en/in1/in2；make flash / flash-f） |
| `uart_loopback/` | i5 的 UART 回环实验 |

---

## 相关（上级目录）

```
hardware/tvns-stim-bringup-2026-09-23.md   bench 动手记录（第1~9步 + 拓扑级发现）
hardware/FORGET.md                          踩坑清单（A 段全是刺激侧教训）
hardware/RETROSPECTIVE.md                   复盘（焊SMD/买假货/囤料三坑）
hardware/BOM.md                             物料台账
```

---

*新文稿进来时，先在这张表里登记"它是什么/是否当前"。*
