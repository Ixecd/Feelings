# Feelings 技术架构

> 作者：qc
> 日期：2026-04-05（更新）
> 状态：早期设计，持续演进

---

## 一、架构全景

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

每一层职责清晰，技术选型不同，边界明确。

---

## 二、Layer 0：设备套件

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

设备间通信：BLE mesh，耳后设备为主，其他向主设备注册。
多设备信号同步精度：**专项研究问题**，标准BLE无法满足理论需求，待硬件专项研究（见 `docs/device-architecture.md`）。

---

## 三、Layer 1：硬件 / 固件层

**职责**：直接操控每个设备的神经接口硬件，采集和输出神经信号。

```
语言        C / C++ / Rust
运行时      实时操作系统（FreeRTOS 或类似）
通信        蓝牙 BLE / 有线接口
```

**核心要求**：微秒级响应，fail-safe故障模式，低功耗，主设备掉线时所有从设备立即停止信号输出。

---

## 四、Layer 2：信号处理层

**职责**：将原始神经信号转化为感受模式，将感受配置转化为神经刺激参数。在本地设备运行，原始信号永远不离开设备。

```
研究阶段    Python + NumPy / SciPy / PyTorch
产品阶段    C++ / Rust（性能确定性，无GC）
推理加速    ONNX Runtime / TensorRT
```

**Layer 2 的核心工作**：

```
采集方向    原始生理信号 → 感受曲线（实时）
            多设备信号融合 → 统一感受状态表示

注入方向    感受包参数 → 各设备的刺激参数
            感受曲线 → AI 音乐生成参数（实时，驱动服务器AI）

闭环处理    感受曲线 → 个人基准更新
            当前状态 vs 个人基准 → 安全判断（动态窗口机制）
            自省报告 → 基准内部解读层融合
```

---

## 五、Layer 3：应用服务层

**职责**：用户系统、设备套件管理、感受配置编排、数据存储、榜单、音乐AI、音乐平台合作接口、自省、时间维度、社会层。

```
语言        Go
数据库      PostgreSQL（业务数据）+ etcd（分布式状态）
部署        KubePivot
```

**核心模块**：

```
feelings-server/
├── cmd/feelings/
├── internal/
│   ├── api/               # HTTP API + WebSocket（多人会话实时同步）
│   ├── device/            # 设备套件管理（多设备注册/状态/协作）
│   ├── session/           # 感受会话（开始/暂停/结束/历史）
│   ├── pattern/           # 感受包库（存储/检索/评分/设备依赖/混音结构）
│   ├── baseline/          # 个人基准管理（本地计算结果元数据同步）
│   ├── safety/            # 安全事件记录、动态窗口状态管理
│   ├── leaderboard/       # 榜单系统（多维度/区域动态分区）
│   ├── music/             # AI音乐生成接口 + 音乐平台合作接口
│   ├── introspection/     # 自省报告存储和分析
│   ├── temporal/          # 时间维度（心动模式/季节/成长轨迹/生日）
│   ├── social/            # 社会层（多人体验会话/感受包分享/评论）
│   ├── user/              # 用户系统（认证/权限）
│   └── billing/           # 计费
├── migrations/
└── configs/
```

---

## 六、完整数据模型

```sql
-- 感受包（含设备依赖和混音结构）
CREATE TABLE feeling_patterns (
    id                  UUID PRIMARY KEY,
    name                TEXT NOT NULL,
    narrative           TEXT,
    category            TEXT,
    structural_tags     JSONB,              -- 七维结构性参数
    signal_config       JSONB,              -- 下发给 Layer 2 的参数
    primary_signal      JSONB,              -- 主旋律感受 + 权重
    secondary_signals   JSONB,              -- 点缀感受数组 [{feeling, weight}]
    core_score          FLOAT,              -- AI 内核置信度 0-1
    intensity_nominal   INT,                -- 标称强度 1-100（单一值，非范围）
    intensity_version   INT DEFAULT 1,      -- 评分版本号
    device_requirements JSONB,              -- 设备依赖 + 降级描述
    likes_count         INT DEFAULT 0,      -- 爱心数量（对创作者可见）
    comments_count      INT DEFAULT 0,      -- 评论数量（对创作者可见）
    created_by          UUID,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 感受会话
CREATE TABLE feeling_sessions (
    id                  UUID PRIMARY KEY,
    user_id             UUID NOT NULL,
    device_set_id       UUID NOT NULL,
    pattern_id          UUID NOT NULL,
    social_session_id   UUID,               -- 如果是多人体验，关联社会会话
    started_at          TIMESTAMPTZ,
    ended_at            TIMESTAMPTZ,
    intensity_actual    INT,                -- 实际感受强度（基于生理数据）
    feedback            JSONB,              -- 用户事后主观反馈
    safety_events       JSONB,              -- 本次触发的安全事件
    music_mode          TEXT                -- 'ai_generated'/'local'/'none'
);

-- 设备
CREATE TABLE devices (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    hardware_id      TEXT UNIQUE,
    device_type      TEXT NOT NULL,         -- 'ear'/'neck'/'wrist'/'temple'
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
    coverage_level   TEXT,                  -- 'basic'/'standard'/'full'
    updated_at       TIMESTAMPTZ
);

-- 个人基准元数据（Layer 2 本地计算，Layer 3 存储元数据）
CREATE TABLE user_baselines (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    version          INT DEFAULT 1,
    session_count    INT,
    maturity_level   TEXT,                  -- 'learning'/'developing'/'mature'
    intensity_window INT,                   -- 当前动态强度窗口上限
    updated_at       TIMESTAMPTZ
);

-- 安全事件记录
CREATE TABLE safety_events (
    id               UUID PRIMARY KEY,
    session_id       UUID NOT NULL,
    user_id          UUID NOT NULL,
    event_level      INT,                   -- 1-4
    trigger_signal   TEXT,
    action_taken     TEXT,
    window_before    INT,                   -- 事件前的动态窗口值
    window_after     INT,                   -- 事件后的动态窗口值（回退后）
    occurred_at      TIMESTAMPTZ
);

-- 自省报告
CREATE TABLE introspection_reports (
    id               UUID PRIMARY KEY,
    session_id       UUID NOT NULL,
    user_id          UUID NOT NULL,
    responses        JSONB,                 -- 各层引导问题的回答
    vocabulary_score INT,                   -- 感受词汇丰富度评分
    body_awareness   TEXT,                  -- 身体定位描述
    life_connection  TEXT,                  -- 生活关联描述
    surprises        TEXT,                  -- 意外描述
    skipped          BOOLEAN DEFAULT FALSE,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 基准时间序列快照（成长轨迹）
CREATE TABLE baseline_snapshots (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    snapshot_date    DATE NOT NULL,
    intensity_window INT,                   -- 当时的动态窗口值
    maturity_level   TEXT,
    dominant_feelings JSONB,                -- 当时的主导感受类型
    feeling_gaps     JSONB,                 -- 当时的感受空白
    vocabulary_score INT,                   -- 当时的自省词汇评分
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 多人体验会话（社会层）
CREATE TABLE social_sessions (
    id               UUID PRIMARY KEY,
    pattern_id       UUID NOT NULL,
    initiator_id     UUID NOT NULL,
    participants     UUID[],                -- 参与用户ID列表（最多6人）
    status           TEXT,                  -- 'waiting'/'active'/'discussing'/'ended'
    started_at       TIMESTAMPTZ,
    ended_at         TIMESTAMPTZ,
    discussion_room  TEXT                   -- 讨论空间的实时连接标识
);

-- 感受包评论
CREATE TABLE pattern_comments (
    id               UUID PRIMARY KEY,
    pattern_id       UUID NOT NULL,
    user_id          UUID NOT NULL,
    content          TEXT,
    is_anonymous     BOOLEAN DEFAULT TRUE,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 音乐感受档案元数据（AI分析结果，本体存设备本地）
CREATE TABLE music_feeling_profiles (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    data_sources     TEXT[],                -- ['netease', 'spotify']
    dominant_feelings JSONB,
    feeling_gaps     JSONB,
    intensity_comfort JSONB,                -- {min: int, max: int}
    music_prefs      JSONB,                 -- 偏好音色/节奏/和声参数
    last_synced      TIMESTAMPTZ,           -- 最近一次从设备同步元数据的时间
    updated_at       TIMESTAMPTZ
);
```

---

## 七、Layer 4：客户端层

```
移动端    Swift（iOS）/ Kotlin（Android）
          设备管理、感受体验、个人基准可视化、自省引导
          本地音乐库分析（音频数据不上传）
          本地基准数据加密存储

Web 端    TypeScript + React
          榜单查看、感受档案、音乐平台授权管理、年度回顾
```

---

## 八、感受闭环的技术映射

```
用户体验感受
    Layer 0    设备套件采集生理信号
    Layer 1    固件实时传输原始信号
    Layer 2    信号处理，生成感受曲线

感受曲线反哺
    Layer 2    本地更新个人基准
               实时驱动 AI 音乐生成（信号发往服务器AI）
               实时执行安全判断（动态窗口机制）
               融合自省报告（体验后）
    Layer 3    存储会话记录和安全事件
               更新动态窗口状态
               汇聚脱敏数据，更新感受包公共评分

多人会话
    Layer 3    WebSocket 实时同步（各参与者的会话状态）
               etcd 分布式状态（多人会话的一致性保证）
               各参与者的安全机制完全独立运行
               体验结束后创建讨论空间（独立实时连接）
```

---

## 九、AI音乐生成的架构位置

```
Layer 2（本地）    实时感受曲线生成 → 发送曲线参数至服务器
Layer 3（服务器）  AI音乐生成引擎 → 实时生成音乐流 → 返回设备播放
本地音乐模式       Layer 3 AI 不参与，Layer 2 只做轻量本地适配
```

延迟目标：曲线参数发出到音乐流返回 < 20ms（硬件研究阶段的关键指标）。

---

## 十、数据隐私架构

```
原始神经信号        永远不离开设备（Layer 1/2 本地处理）
个人基准            本地存储，加密，用户完全控制
感受曲线参数        发往服务器用于AI音乐生成，不持久化
音乐平台数据        通过API流经服务器做分析，不持久化原始数据
自省报告            本地存储，可选择性分享给治疗师
基准时间序列        本地存储，Layer 3 只保存元数据快照

上传至服务器（持久化）
    脱敏群体统计数据    感受包公共评分校准
    会话元数据          时长/感受包ID/设备组合（不含生理数据）
    安全事件记录        系统优化（不含原始信号）
    用户可选择退出所有上传
```

---

## 十一、当前阶段重点

```
✅ 产品边界清晰
✅ 技术架构更新
✅ 核心设计文档体系完整
⬜ 顶层设计对齐（文档矛盾审查完成，待product-boundary.md命名修正）
⬜ Layer 3 第一版 API 设计
⬜ feelings-server 仓库初始化（kp init）
⬜ 基础数据模型实现

下一步
⬜ Layer 2 研究：第一个可采集复现的感受模式
⬜ 硬件选型：EEG 头环作为颞部设备原型
⬜ 设备信号同步专项研究
⬜ AI音乐生成延迟验证（目标 < 20ms）
```

---

## 十二、关联文档索引

```
docs/
├── product-boundary.md         个体感受层 vs 关系感受层（⚠️ Layer命名待修正）
├── device-architecture.md      设备套件设计，分工与协作协议
├── closed-loop.md              感受闭环，五路反哺系统
├── safety-system.md            安全体系，TCP窗口模型，犟种协议
├── usage-contract.md           使用契约，戴上即授权
├── contrast-protocol.md        盲选强度，反差感受设计
├── intensity-scale.md          100档对数分布，四区间解锁
├── scoring-engine.md           强度评分引擎，动态重打分
├── feeling-taxonomy.md         感受分类体系，双入口检索
├── feeling-example-happiness.md 快乐解剖，感受混音结构示例
├── music-system.md             音乐系统，三层架构
├── music-partnership.md        音乐平台合作，AI跑在服务器
├── leaderboard-region.md       榜单与区域划分
├── introspection.md            自省系统，反依赖设计
├── temporal-system.md          时间维度，心动模式 + 生日
├── social-layer.md             社会传播，多人体验设计
├── trauma-protocol.md          创伤协议，互补心理治疗
├── posture-plasticity.md       体态可塑性研究
└── tech-architecture.md        本文档

根目录
├── Feelings-PHILOSOPHY.md
├── Feelings-README.md
├── Feelings-ROADMAP.md
├── Feelings-HARD-PROBLEMS.md
└── Feelings-PASS.md
```

---

## 十三、和 KubePivot 的关系

```
KubePivot = Feelings 的 CD 基础设施

kp init --name feelings-server --module github.com/Ixecd/feelings-server
kp deploy
kp status
kp diff --drift

KubePivot 管部署，Feelings 专注感受。地基已经在了。
```
