# Feelings 技术架构

> 作者：qc
> 日期：2026-04-05（更新自 2026-04-04）
> 状态：早期设计，持续演进

---

## 一、架构全景

Feelings 是一个感受民主化平台，技术上需要跨越从硬件到云端的完整栈。

```
用户
  ↓
客户端（移动端 / Web）                    ← Layer 4
  ↓
Layer 3：应用服务层                       ← Go 主场，现阶段重点
  ↓
Layer 2：信号处理层                       ← Python（研究）→ C++/Rust（产品）
  ↓
Layer 1：硬件 / 固件层                    ← C/C++，实时操作系统
  ↓
设备套件（耳后 / 后颈 / 腕部 / 颞部）     ← 协作运行，缺了少那部分功能
```

每一层职责清晰，技术选型不同，边界明确——上层不需要知道下层的实现细节。

**核心变更**：Feelings 不是一个设备，是一套设备。每个设备负责特定的神经通路和信号维度，协作运行，缺了少那部分功能，不影响其他。详见 `docs/device-architecture.md`。

---

## 二、Layer 0：设备套件

> 新增层，原文档未包含。

**职责**：多设备协作，覆盖不同神经通路，采集和输出不同维度的感受信号。

```
耳后设备（必选·主设备）
    迷走神经耳支 / 情绪基调 / 心率采集 / 音乐信号通路

后颈设备
    脊髓背根 / 本体感受注入 / 体温 + 运动采集

腕部设备
    外周神经 / 细粒度情绪信号 / 皮肤电导精确采集

颞部设备
    颞叶皮层 / 专注冥想类感受 / EEG 初步采集

未来设备
    随神经科学进展定义，协议预留扩展位
```

设备间通信：BLE mesh，耳后设备为主，其他设备向主设备注册。信号时钟同步误差 < 1ms。

---

## 三、Layer 1：硬件 / 固件层

**职责**：直接操控每个设备的神经接口硬件，采集和输出神经信号。

**技术选型**：
```
语言        C / C++ / Rust
运行时      实时操作系统（FreeRTOS 或类似）
通信        蓝牙 BLE / 有线接口
```

**核心要求**：
- 实时性：微秒级响应，不能有任何不可预期的延迟
- 安全性：直接作用于人体，故障模式必须是安全的（fail-safe，不是 fail-open）
- 低功耗：可穿戴设备的电池限制
- 主设备掉线：所有从设备立即停止信号输出

**当前状态**：研究阶段，硬件形态未定。

---

## 四、Layer 2：信号处理层

**职责**：将原始神经信号转化为感受模式，将感受配置转化为神经刺激参数。在本地设备运行，原始信号永远不离开设备。

**为什么不用 Go**：Go 的 GC 哪怕停顿 < 1ms，在实时神经信号处理里也是不可接受的。

```
研究阶段    Python + NumPy / SciPy / PyTorch
            神经科学领域的事实标准，生态最完整

产品阶段    C++ / Rust
            性能确定性，无 GC，可嵌入固件

推理加速    ONNX Runtime / TensorRT
            Python 训练的模型导出，C++ 里推理
```

**Layer 2 的核心工作**：

```
采集方向    原始生理信号 → 感受曲线（实时）
            多设备信号融合 → 统一感受状态表示

注入方向    感受包参数 → 各设备的刺激参数
            感受曲线 → AI 音乐生成参数（实时）

闭环处理    感受曲线 → 个人基准更新
            当前状态 vs 个人基准 → 安全判断
```

**核心问题（待研究）**：
- 如何采集「已知感受」对应的神经信号模式？
- 多设备信号如何融合为统一的感受状态表示？
- 个体差异有多大？模型需要个性化吗？（答案：是，见 `docs/closed-loop.md`）

---

## 五、Layer 3：应用服务层

**职责**：用户系统、设备套件管理、感受配置编排、数据存储、榜单、音乐平台合作接口。

**这是当前阶段的重点，也是 Go 的主场。**

```
语言        Go
数据库      PostgreSQL（业务数据）+ etcd（分布式状态）
部署        KubePivot（CD 基础设施已就绪）
```

**核心模块**：

```
feelings-server/
├── cmd/feelings/
├── internal/
│   ├── api/               # HTTP API
│   ├── device/            # 设备套件管理（多设备注册/状态/协作）
│   ├── session/           # 感受会话（开始/暂停/结束/历史）
│   ├── pattern/           # 感受包库（存储/检索/评分/设备依赖）
│   ├── baseline/          # 个人基准管理（本地计算结果同步）
│   ├── safety/            # 安全事件记录和分析
│   ├── leaderboard/       # 榜单系统（多维度/区域动态分区）
│   ├── music/             # 音乐平台合作接口
│   ├── user/              # 用户系统（认证/权限）
│   └── billing/           # 计费
├── migrations/
└── configs/
```

**数据模型（更新版）**：

```sql
-- 感受包（含设备依赖和混音结构）
CREATE TABLE feeling_patterns (
    id                  UUID PRIMARY KEY,
    name                TEXT NOT NULL,
    narrative           TEXT,                   -- 上传者叙事
    category            TEXT,
    structural_tags     JSONB,                  -- 七维结构性参数
    signal_config       JSONB,                  -- 下发给 Layer 2 的参数
    primary_signal      JSONB,                  -- 主旋律感受 + 权重
    secondary_signals   JSONB,                  -- 点缀感受数组
    core_score          FLOAT,                  -- AI 内核置信度 0-1
    intensity_nominal   INT,                    -- 标称强度 1-100
    intensity_version   INT DEFAULT 1,          -- 评分版本号
    device_requirements JSONB,                  -- 设备依赖 + 降级描述
    created_by          UUID,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 感受会话（含设备组合记录）
CREATE TABLE feeling_sessions (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL,
    device_set_id   UUID NOT NULL,              -- 本次使用的设备组合
    pattern_id      UUID NOT NULL,
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    intensity_actual INT,                       -- 实际感受强度（基于生理数据）
    feedback        JSONB,                      -- 用户事后主观反馈
    safety_events   JSONB,                      -- 本次触发的安全事件
    music_mode      TEXT                        -- 'ai_generated'/'local'/'none'
);

-- 设备（支持套件）
CREATE TABLE devices (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    hardware_id      TEXT UNIQUE,
    device_type      TEXT NOT NULL,             -- 'ear'/'neck'/'wrist'/'temple'
    firmware_version TEXT,
    is_primary       BOOLEAN DEFAULT FALSE,
    capabilities     JSONB,
    status           TEXT DEFAULT 'offline',
    last_seen        TIMESTAMPTZ
);

-- 用户当前设备组合
CREATE TABLE device_sets (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    active_devices   UUID[],
    coverage_level   TEXT,                      -- 'basic'/'standard'/'full'
    updated_at       TIMESTAMPTZ
);

-- 个人基准（Layer 2 本地计算，Layer 3 存储元数据）
CREATE TABLE user_baselines (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    version          INT DEFAULT 1,
    session_count    INT,                       -- 基准建立的会话数
    maturity_level   TEXT,                      -- 'learning'/'developing'/'mature'
    updated_at       TIMESTAMPTZ
);

-- 安全事件记录
CREATE TABLE safety_events (
    id               UUID PRIMARY KEY,
    session_id       UUID NOT NULL,
    user_id          UUID NOT NULL,
    event_level      INT,                       -- 1-4
    trigger_signal   TEXT,
    action_taken     TEXT,
    occurred_at      TIMESTAMPTZ
);
```

---

## 六、Layer 4：客户端层

**职责**：用户交互界面，设备套件配套 App。

```
移动端    Swift（iOS）/ Kotlin（Android）
          设备管理、感受体验、个人基准可视化
          本地音乐库分析（音频数据不上传）

Web 端    TypeScript + React
          榜单查看、感受档案、音乐平台授权管理
```

**当前状态**：未启动，等 Layer 3 API 稳定后再做。

---

## 七、感受闭环的技术映射

感受闭环（见 `docs/closed-loop.md`）在各层的技术实现：

```
用户体验感受
    Layer 0    设备套件采集生理信号
    Layer 1    固件实时传输原始信号
    Layer 2    信号处理，生成感受曲线

感受曲线反哺
    Layer 2    本地更新个人基准
               实时驱动 AI 音乐生成
               实时执行安全判断
    Layer 3    存储会话记录和安全事件
               汇聚脱敏数据，更新感受包公共评分

安全判断
    Layer 2    当前数据 vs 个人基准，本地判断
    Layer 1    固件层执行降档或停止信号
    Layer 3    记录安全事件，影响后续解锁评估
```

---

## 八、数据隐私架构

```
原始神经信号        永远不离开设备（Layer 1/2 本地处理）
个人基准            本地存储，加密，用户完全控制
感受曲线            本地处理，不上传
本地音乐分析结果    本地存储，不上传音频数据

上传至服务器
    脱敏后的群体统计数据    用于感受包公共评分校准
    会话元数据              时长、感受包 ID、设备组合（不含生理数据）
    安全事件记录            用于系统优化（不含原始信号）
    用户可选择退出所有上传
```

---

## 九、当前阶段重点

```
现在
  ✅ 产品边界清晰（docs/product-boundary.md）
  ✅ 技术架构更新（含设备套件 + 闭环 + 安全体系）
  ✅ 核心设计文档体系完整
  ⬜ 顶层设计对齐（所有文档矛盾审查）
  ⬜ Layer 3 第一版 API 设计
  ⬜ feelings-server 仓库初始化（kp init）
  ⬜ 基础数据模型实现

下一步
  ⬜ Layer 2 研究：找到第一个可以采集和复现的简单感受模式
  ⬜ 硬件选型：从现有非侵入式设备开始（EEG 头环作为颞部设备原型）
  ⬜ 第一个 demo：采集「专注」状态，尝试在另一个人身上复现

最终目标
  「让每个人都能体验到不同的感受」
  感受这件事，对每个人都公平。
```

---

## 十、关联文档索引

```
docs/
├── product-boundary.md         个体感受 vs 关系感受，两层产品架构
├── device-architecture.md      设备套件设计，分工与协作协议
├── closed-loop.md              感受闭环，神经信号反哺系统
├── safety-system.md            安全体系，四级响应，犟种协议
├── usage-contract.md           使用契约，戴上即授权
├── contrast-protocol.md        盲选强度，反差感受设计
├── intensity-scale.md          100档对数分布，四区间解锁
├── scoring-engine.md           强度评分引擎，动态重打分
├── feeling-taxonomy.md         感受分类体系，双入口检索
├── feeling-example-happiness.md 快乐解剖，感受混音结构示例
├── music-system.md             音乐系统，三层架构
├── music-partnership.md        音乐平台合作，听歌数据→感受档案
├── leaderboard-region.md       榜单与区域划分
├── posture-plasticity.md       体态可塑性与 Feelings 介入逻辑
└── tech-architecture.md        本文档

根目录
├── Feelings-PHILOSOPHY.md      产品哲学
├── Feelings-README.md          项目介绍
├── Feelings-ROADMAP.md         路线图
├── Feelings-HARD-PROBLEMS.md   硬骨头文档
└── passing-score.md            十分及格，价值观声明
```

---

## 十一、和 KubePivot 的关系

```
KubePivot = Feelings 的 CD 基础设施

kp init --name feelings-server --module github.com/Ixecd/feelings-server
kp deploy
kp status
kp diff --drift

KubePivot 管部署，Feelings 专注感受。
地基已经在了。
```
