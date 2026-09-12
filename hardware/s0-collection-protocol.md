# S0 采集协议：个体基线的采集规范

> 作者：qc ｜ 日期：2026-09-12
> 定位：S0「建个体基线」的采集规范——**哪些参数必须固定、哪些必须记录、数据长什么样**。
> 目的：让两次会话**可比**；让 `baseline.py` 能判断"这份会话算不算同条件"。
> 关联：`mvp-vagus-loop-2026-09-11.md`（S0~S3）、`FORGET.md`（PPG 踩坑）、`docs/architecture/frame-protocol.md`（设备帧，另一层）

---

## 〇、一句话

**基线可比性 = 控制变量（固定）+ 协变量（记录）。** 现在 `baseline.json` 只存了文件名和 HR/SDNN，
**没有任何条件信息**——这是当前最大的缺口。本协议补上它。

---

## 一、会话参数（协议层，最关键）

### 1.1 控制变量（必须固定，否则会话不可比）

| 参数 | 取值示例 | 说明 |
|---|---|---|
| 体位 | 坐 / 躺 | 坐/躺 HRV 不同，不能混 |
| 时段 | 起床后 30min | 昼夜节律影响 HRV |
| 餐后间隔 | ≥120min | 消化影响自主神经 |
| 时长 | 见 §四 | 决定 SDNN 口径 |
| 环境 | 安静 / 遮光 | 光、声都是伪迹源 |
| 传感器位置 | 指 / 耳 | 指/耳波形不同 |
| 固定方式 | 胶带 | 松紧直接决定 DC/幅度 |

### 1.2 协变量（必须记录，用于分组/回归）

```
日期时间 · 时长 · 餐后分钟 · 咖啡因/酒精/尼古丁(近 N h)
昨晚睡眠时长 · 距上次运动(h) · 药物 · 室温/噪声
```

### 1.3 设备参数（记录）

```
device · 固件版本/hash · fs_nominal(100) · 波特率(9600) · LED电流(7.2mA)
sensor_site · 是否遮光 · 接触DC(会话均值)
```

### 1.4 主观（记录）

```
自评 1–10（紧张↔放松） · 备注一句话
```

### 1.5 判定（机器填）

```
session_id · gate 总评 · 是否纳入基线
```

---

## 二、样本字段（CSV 每行）

现状（**9 列**——已并入 accel）：

```
t, idx, red, beat, ibi_samples, ibi_ms, ax, ay, az
```

**追加字段（向后兼容——解析只读 t/red，加列不破坏）：**

| 字段 | 何时加 | 含义 |
|---|---|---|
| `ax,ay,az` | ✅ 已落 CSV | 三轴加速度（i16，±2g，16384 LSB/g）→ 质量门"运动窗"用它 |
| `cnt` | 硬件时基落地后 | 设备样本计数器（IBI = Δcnt / fs） |
| `dc` | 可随时 | 运行中 DC（接触监测；现在只在 report 里，不落盘） |
| `motion` | 运动抑制落地后 | 逐窗运动标记（现由 accel 在门里实时算） |
| `sq` | 可选 | 逐拍质量(SQI) |

---

## 三、会话元数据（sidecar JSON）

每份 CSV 配一个 `hrv_log_<时间戳>.meta.json`，由 `hrv_monitor.py --meta` 生成：

```bash
python3.14 hrv_monitor.py /dev/cu.usbserial-0001 180 100 \
  --meta "posture=sitting,since_meal_min=120,caffeine=false,sleep_h=7.5,last_exercise_h=20,self_state=6"
```

模板（协议 + 验收 + 派生量）：

```json
{
  "session_id": "2026-09-12T10:49:29",
  "csv": "hrv_log_20260912-104929.csv",
  "protocol": {
    "device": "iCESugar+MAX30102", "fw": "max30102_stream.bin",
    "fs_nominal": 100, "baud": 9600, "led_ma": 7.2,
    "site": "finger", "fixation": "tape", "light_blocked": true,
    "posture": "sitting", "dur_s": 180,
    "since_meal_min": 120, "caffeine": false, "sleep_h": 7.5,
    "last_exercise_h": 20, "self_state": 6, "note": ""
  },
  "quality": {
    "gate": "WARN",
    "checks": {"帧率": "PASS", "接触DC": "PASS", "漂移/脉搏": "PASS",
               "主峰落位": "PASS", "检测率": "PASS", "SDNN稳定": "WARN", "节律强度": "PASS"},
    "dc_mean": 115644, "fs_measured": 99.9, "motion_pct": null
  },
  "derived": {"hr": 78.3, "sdnn": 63.2, "n_beat": 197, "n_samp": 17988}
}
```

> `--meta` 也支持 `@file.json`（把一份基线协议 JSON 读进来）。
> `motion_pct` 待 MPU6050 接入后填。

---

## 四、纳入 / 排除规则（写死，别每次拍脑袋）

```
纳入   gate = PASS（WARN 默认不进；要进必须显式标注并单独分组）
独立   每天 ≤1 次、固定时段 → 满足"样本独立"（N=6 同晨不独立那条教训的解）
时长   ≥5min（配 5-min SDNN）；<5min 一律标注"短窗 SDNN，不可比临床"
排除   中途失联 / DC 越界 / 明显运动 / 主观不适
```

---

## 五、命名与目录

```
hrv_log_<YYYYMMDD-HHMMSS>.csv        采集数据
hrv_log_<YYYYMMDD-HHMMSS>.meta.json  会话元数据（--meta 生成）
baseline.json                         聚合结果（后续改为读 meta 判条件）
```

---

## 六、当前进度与硬件落点

| 项 | 状态 |
|---|---|
| 采集 → 验收（`hrv_monitor` → `quality_gate`） | ✅ 通（真板跑过 6 份） |
| 会话参数固定（§1.1） | ⬜ 待你定取值 |
| 会话元数据 sidecar（§3） | ✅ `--meta` 已实现 |
| 纳入规则（§4） | ⬜ 待定 |
| 跨天采集（独立性） | ⬜ 待做 |
| MPU6050（accel → 运动抑制） | ✅ 已接入：流固件发 `FE E2`(accel)+`FE E3`(WHO)；PC 出 `motion_pct`（见 mpu6050-bringup） |
| 硬件时基 / 长时环形存储 | ⬜ 路线图后续（见 ROADMAP） |

---

*基线不是"多采几次"就行——是"每次都在同样的条件下采、并且记下来"。这份协议管的就是这件事。*
