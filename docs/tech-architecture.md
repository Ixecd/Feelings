# Feelings 技术架构

> 作者：qc
> 日期：2026-04-11（全量重写）
> 状态：早期设计，持续演进

---

## 一、架构全景

```
用户
  ↓
客户端（移动端 / Web）                           ← Layer 4
  ↓
Layer 3：应用服务层                              ← Go 主场，现阶段重点
  ↓
Layer 2：信号处理层 + 四诊感知层                 ← Python（研究）→ C++/Rust（产品）
  ↓
Layer 1：硬件 / 固件层                           ← C/C++，实时操作系统
  ↓
设备套件（耳后必选 + 后颈 + 腕部 + 颞部）        ← 协作运行，缺了少那部分功能
+ 感知扩展（摄像头 + 麦克风）                    ← 四诊合参的望和闻
+ 长期扩展（触觉设备 + 嗅觉传感器）              ← 路径A，待技术成熟
```

每一层职责清晰，技术选型不同，边界明确。上层不需要知道下层的实现细节。

---

## 二、Layer 0：设备套件

**职责**：多设备协作，覆盖不同神经通路，采集和输出不同维度的感受信号。

### 核心设备（当前）

```
耳后设备（必选·主设备）
    迷走神经耳支 / 情绪基调 / 心率采集 / 音乐信号通路
    这是唯一的必选设备，其他都是扩展

后颈设备
    脊髓背根 / 本体感受注入 / 体温 + 运动采集

腕部设备
    外周神经 / 细粒度情绪信号 / 皮肤电导精确采集

颞部设备
    颞叶皮层 / 专注冥想类感受 / EEG 初步采集
```

### 四诊感知扩展

```
摄像头（望）
    面部微表情识别 / 瞳孔大小 / 眨眼频率 / 体态
    设计原则：伙伴的眼睛，不是监控摄像头
    数据处理：本地，不离开设备
    用户可随时关闭，不影响其他功能

麦克风（闻）
    语调分析 / 语速检测 / 呼吸节律识别
    数据处理：本地实时处理，不录制存储
    用户可随时关闭
```

### 长期扩展方向（路径A，待技术成熟）

```
触觉扩展设备
    触觉背心（大面积皮肤压力模拟）
    触觉手套（手部高密度感受器覆盖）
    面部设备（面部极高密度感受器）
    全身触觉层（分区独立控制）
    解决：被拥抱感、亲密感受等当前「轮廓版」体验的完整化

嗅觉传感器
    环境气味感知
    配合个人气味-感受档案建立
    嗅觉直通边缘系统，是感受触发的直接通路
    当前：设备协议预留接口，等待传感器技术成熟
```

### 设备协作协议

```
主设备选举    耳后设备永远是主设备
              其他设备向主设备注册，成为从设备

信号同步      ⚠️ 专项研究问题
              目标：时钟同步误差 < 1ms
              约束：标准BLE最小连接间隔7.5ms，无法直接满足
              待研究方向：专有无线协议 / UWB时间同步 / 软件补偿

掉线处理      从设备掉线 → 降级，不中断体验
              主设备掉线 → 立即终止所有信号输出
```

---

## 三、Layer 1：硬件 / 固件层

**职责**：直接操控每个设备的神经接口硬件，采集和输出神经信号。

```
语言        C / C++ / Rust
运行时      实时操作系统（FreeRTOS 或类似）
通信        蓝牙 BLE / 有线接口
```

**三阶段硬件路线**

```
第一阶段（非侵入·当前可做）
    EEG头环/贴片    消费级，96%+准确率，<50ms延迟
    tDCS/TMS        经颅直流/磁刺激，靶向情绪调节
    迷走神经刺激    耳后设备，已有临床验证
    参考产品        深眠π / 梦邻枕头 / BrainCo
    ↓ 这是阶段零原型的起点

第二阶段（半侵入·5年）
    硬膜外贴片      不开颅，不碰脑组织，硬币大小
    无线供能        无需充电，长期植入
    信号精度        97-99%，单神经元级
    参考产品        北脑一号 / 清华NEO

第三阶段（微侵入·10年）
    注射式纳米芯片  静脉注射，穿越血脑屏障
    可吞咽芯片      永久植入，无创伤
    参考路线        MIT 2025注射式微米级芯片
```

**核心要求**：
- 实时性：微秒级响应，不能有任何不可预期的延迟
- 安全性：直接作用于人体，故障模式必须是 fail-safe，不是 fail-open
- 低功耗：可穿戴设备的电池限制
- 主设备掉线：所有从设备立即停止信号输出
- **开源优先**：硬件电路和固件代码全部开源，MIT协议，不做专利围墙

**当前状态**：第一阶段硬件选型中，优先选用已有开源方案的组件。

---

## 四、Layer 2：信号处理层 + 四诊感知层

**职责**：将原始神经信号转化为感受模式；将感受配置转化为神经刺激参数；四诊合参，生成综合感受状态。在本地设备运行，原始信号永远不离开设备。

### 技术选型

```
研究阶段    Python + NumPy / SciPy / PyTorch
产品阶段    C++ / Rust（无GC，性能确定性）
推理加速    ONNX Runtime / TensorRT
```

### 核心工作

**信号处理（切）**

```
采集方向    原始生理信号 → 感受曲线（实时）
            多设备信号融合 → 统一感受状态表示

注入方向    感受包参数 → 各设备的刺激参数
            感受曲线 → AI 音乐生成参数（实时）

闭环处理    感受曲线 → 个人基准更新
            当前状态 vs 个人基准 → 安全判断
```

**四诊感知融合（望闻问切）**

```
切（权重最高）    生理传感器数据
                  最难伪装，是锚点
                  说「发生了什么」，不说「为什么」

闻               语调分析（信息密度最高）
                  语速检测
                  呼吸节律识别
                  环境气味（长期扩展）

望               面部微表情识别
                  瞳孔大小变化
                  眨眼频率
                  体态分析

问（权重最低）    自省报告 / AI教练对话
                  语言层最容易被理性过滤
                  但「说不清楚的地方」是最有价值的信号
```

**矛盾点检测**

```
四诊一致        高置信度判断，正常处理
四诊不一致      矛盾点检测介入
                优先信「切」，切和闻同向时几乎可以确认
                矛盾点是最有价值的信号：
                「不一致的时候，才是最真的时候」
```

**感受包处理**

```
混音结构解析    主旋律 + 点缀配比
感受形状识别    七种基本形状 + 子类
强度校准        基于个人基准的实际强度计算
TCP慢启动       起点极低，指数增长，异常退避
```

---

## 五、Layer 3：应用服务层

**职责**：用户系统、设备套件管理、感受配置编排、数据存储、榜单、音乐平台合作、AI对话接入等。

**这是当前阶段的重点，也是 Go 的主场。**

```
语言        Go
数据库      PostgreSQL（业务数据）+ etcd（分布式状态）
部署        KubePivot（CD 基础设施已就绪）
```

### 核心模块

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
│   ├── music/             # 音乐平台合作接口（服务器端AI分析）
│   ├── introspection/     # 自省报告存储和分析
│   ├── temporal/          # 时间维度（基准时间序列/心动模式/生日/状态周期）
│   ├── social/            # 社会层（多人体验会话/评论/爱心）
│   ├── trauma/            # 创伤协议（独立解锁路径/援助触发）
│   ├── ai_integration/    # AI对话接入（感受过滤引擎/持续同步）
│   ├── interest/          # 兴趣引导（感受空白匹配真实活动）
│   ├── opportunity/       # 机会制造和参与
│   ├── user/              # 用户系统（认证/权限/年龄验证）
│   └── billing/           # 计费
├── migrations/
└── configs/
```

### 数据模型

```sql
-- 感受包（含设备依赖和混音结构）
CREATE TABLE feeling_patterns (
    id                  UUID PRIMARY KEY,
    name                TEXT NOT NULL,
    narrative           TEXT,
    category            TEXT,
    structural_tags     JSONB,                  -- 七维结构性参数
    signal_config       JSONB,                  -- 下发给 Layer 2 的参数
    primary_signal      JSONB,                  -- 主旋律感受 + 权重
    secondary_signals   JSONB,                  -- 点缀感受数组
    feeling_shape       TEXT,                   -- 七种基本形状 + 子类
    core_score          FLOAT,                  -- AI 内核置信度 0-1
    intensity_nominal   INT,                    -- 标称强度 1-100
    intensity_version   INT DEFAULT 1,          -- 评分版本号
    device_requirements JSONB,                  -- 设备依赖 + 降级描述
    tactile_coverage    TEXT,                   -- 'full'/'outline'（触觉覆盖等级）
    created_by          UUID,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- 感受会话
CREATE TABLE feeling_sessions (
    id              UUID PRIMARY KEY,
    user_id         UUID NOT NULL,
    device_set_id   UUID NOT NULL,
    pattern_id      UUID NOT NULL,
    mode            TEXT,                       -- 'enhancement'/'generation'
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    intensity_actual INT,
    feedback        JSONB,
    safety_events   JSONB,
    music_mode      TEXT,                       -- 'ai_generated'/'local'/'none'
    four_diag_data  JSONB                       -- 四诊摘要（脱敏）
);

-- 设备
CREATE TABLE devices (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    hardware_id      TEXT UNIQUE,
    device_type      TEXT NOT NULL,             -- 'ear'/'neck'/'wrist'/'temple'/'camera'/'mic'/'tactile'
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
    four_diag_level  TEXT,                      -- 'cut_only'/'cut_wen'/'full_four'
    updated_at       TIMESTAMPTZ
);

-- 个人基准
CREATE TABLE user_baselines (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    version          INT DEFAULT 1,
    session_count    INT,
    maturity_level   TEXT,                      -- 'learning'/'developing'/'mature'
    tcp_ceiling      INT,                       -- 当前TCP模型强度上限
    updated_at       TIMESTAMPTZ
);

-- 安全事件
CREATE TABLE safety_events (
    id               UUID PRIMARY KEY,
    session_id       UUID NOT NULL,
    user_id          UUID NOT NULL,
    event_level      INT,                       -- 1-4
    trigger_signal   TEXT,
    action_taken     TEXT,
    occurred_at      TIMESTAMPTZ
);

-- 自省报告
CREATE TABLE introspection_reports (
    id               UUID PRIMARY KEY,
    session_id       UUID NOT NULL,
    user_id          UUID NOT NULL,
    responses        JSONB,
    keywords         TEXT[],                    -- 脱敏关键词
    skipped          BOOLEAN DEFAULT FALSE,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 个人基准时间序列
CREATE TABLE temporal_snapshots (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    snapshot_date    DATE NOT NULL,
    baseline_summary JSONB,
    dominant_feelings TEXT[],
    intensity_ceiling INT,                      -- TCP当日上限
    state_level      TEXT,                      -- 'low'/'normal'/'high'
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 多人体验会话
CREATE TABLE social_sessions (
    id               UUID PRIMARY KEY,
    initiator_id     UUID NOT NULL,
    pattern_id       UUID NOT NULL,
    participant_ids  UUID[],
    started_at       TIMESTAMPTZ,
    ended_at         TIMESTAMPTZ,
    discussion_open  BOOLEAN DEFAULT FALSE,
    status           TEXT DEFAULT 'pending'
);

-- 用户感受档案元数据（AI对话接入）
CREATE TABLE user_feeling_profiles (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    dominant_feelings JSONB,
    feeling_gaps     JSONB,
    intensity_comfort INT[],
    music_prefs      JSONB,
    data_sources     TEXT[],                    -- 授权的AI平台列表
    last_updated     TIMESTAMPTZ
);

-- 感受地图快照
CREATE TABLE feeling_map_snapshots (
    id               UUID PRIMARY KEY,
    user_id          UUID NOT NULL,
    snapshot_date    DATE NOT NULL,
    explored_coords  JSONB,                     -- 已探索的七维坐标
    blank_areas      JSONB,                     -- 感受空白区域
    created_at       TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 六、Layer 4：客户端层

**职责**：用户交互界面，设备套件配套 App。

```
移动端    Swift（iOS）/ Kotlin（Android）
          设备管理、感受体验、感受地图可视化
          本地音乐库分析（音频数据不上传）
          四诊感知本地处理

Web 端    TypeScript + React
          榜单查看、感受档案、音乐平台授权管理
          AI对话接入授权管理
```

**当前状态**：未启动，等 Layer 3 API 稳定后再做。

---

## 七、感受闭环的技术映射

```
用户体验感受
    Layer 0    设备套件采集生理信号 + 四诊感知采集
    Layer 1    固件实时传输原始信号
    Layer 2    信号处理 + 四诊合参 + 矛盾点检测

感受曲线反哺
    Layer 2    本地更新个人基准
               实时驱动 AI 音乐生成
               实时执行安全判断（TCP退避）
    Layer 3    存储会话记录和安全事件
               汇聚脱敏数据，更新感受包公共评分
               AI对话过滤引擎持续同步

增强模式 vs 生成模式
    增强模式    场景在外，Layer 2检测场景，Layer 0增强感受深度
    生成模式    独处在家，Layer 2直接生成完整感受体验
    系统自动判断，支持无缝切换
```

---

## 八、数据隐私架构

```
永远不离开设备
    原始神经信号和生理数据
    原始基准数据
    摄像头原始图像（本地处理后立即丢弃）
    麦克风原始音频（本地处理后立即丢弃）
    感受曲线

上传至服务器（用户授权，脱敏）
    会话元数据（时长/感受包ID/设备组合，不含生理数据）
    安全事件记录（用于系统优化）
    脱敏后的群体统计数据（用于感受包公共评分校准）
    基准元数据（用于榜单计算）

经过服务器但不持久化
    听歌行为数据（AI分析后下发结果，原始数据不留存）
    AI对话过滤摘要（处理后下发本地，服务器不留存）

用户可选择退出所有上传
亲密感受维度数据：额外隔离，不进入任何群体统计
```

---

## 九、当前阶段重点

```
现在
  ✅ 产品边界清晰（docs/product-boundary.md）
  ✅ 技术架构全量更新（本文档）
  ✅ 核心设计文档体系完整（约50份文档）
  ✅ GOVERNANCE红线明确
  ⬜ 顶层设计对齐（所有文档矛盾审查）
  ⬜ Layer 3 第一版 API 设计
  ⬜ feelings-server 仓库初始化（kp init）
  ⬜ 基础数据模型实现

下一步
  ⬜ Layer 2 研究：四诊感知原型
  ⬜ 硬件选型：从现有设备开始（EEG头环 + 摄像头 + 麦克风）
  ⬜ 第一个 demo：采集「专注」状态，尝试复现 + 四诊验证

最终目标
  让每个人都能体验到不同的感受
  感受这件事，对每个人都公平
```

### AI 教练数据的分布式保存

AI 教练对每个用户的了解，是 Feelings 最重要的资产之一——不能因为单个节点故障而丢失。

```
AI教练的数据构成
    个人基准（时序数据）      → TimescaleDB，分片存储
    感受地图快照              → PostgreSQL，多副本
    四诊历史摘要              → PostgreSQL，多副本
    对话历史摘要              → PostgreSQL，多副本
    矛盾点档案                → PostgreSQL，多副本

分布式原则
    每份数据至少3个副本
    副本分布在不同的可用区（AZ）
    主节点故障，自动切换到副本，用户无感知
    数据恢复目标（RPO）< 1分钟
    服务恢复目标（RTO）< 30秒

用户体验层
    永远只有一个AI教练
    即使底层有多个节点在支撑
    用户感知不到分布式的存在
    只感受到「这个教练一直记得我」
```

云原生部署（KubePivot管理）：

```
StatefulSet    AI教练服务的有状态部分
               保证Pod重启后数据连续性

PersistentVolume  数据持久化
                  跨Pod生命周期保存

跨区域备份     定时将关键数据备份到另一个地理区域
               防止整个区域故障导致数据丢失
```

---

## 十四、存储层设计

pg + etcd 不够，需要按数据类型选择合适的存储。

### 数据类型分析

```
结构化数据    用户账号/感受包元数据/分成记录/会话元数据
              → PostgreSQL（继续用，是主数据库）

时序数据      个人基准时间序列/temporal_snapshots
              百万用户 × 365天 × 数年 = 巨量时序数据
              → TimescaleDB（PostgreSQL扩展，不是新系统）

流数据        信号流/感受曲线/实时状态
              Stream First架构，连续高频
              → NATS（消息队列+流处理）

缓存数据      榜单实时计算/会话状态/限流计数
              → Redis

对象数据      AI生成音乐文件/固件二进制/用户导出包/感受包媒体资源
              → MinIO（开源对象存储，S3兼容接口）

分布式状态    设备注册/服务发现/分布式锁
              → etcd（继续用，KubePivot已集成）
```

### 完整存储架构

```
PostgreSQL      主数据库，结构化业务数据
                用户/感受包/分成/安全事件

TimescaleDB     PostgreSQL的时序扩展
                不需要学新技术，pg知识完全复用
                时序查询比普通pg快几十倍
                temporal_snapshots/基准演进

NATS            消息队列 + 流处理
                Stream First架构的核心基础设施
                Go生态最友好的消息系统，轻量
                实时信号流/感受曲线流/AI教练事件流

Redis           缓存 + 实时状态
                榜单实时计算（Sorted Set）
                会话状态（TTL自动清理）
                限流计数器（滑动窗口）

MinIO           对象存储（OSS）
                开源，S3兼容接口，自托管
                数据不交给第三方，符合开源哲学
                AI生成音乐/固件文件/用户数据导出包

etcd            分布式状态（继续）
                设备注册/服务发现/分布式锁
                KubePivot已集成，不变
```

### 选型原则

```
全部开源        不依赖大厂黑盒，数据自主可控
S3兼容          MinIO可以无缝迁移到任何S3兼容存储
Go友好          NATS是Go生态最原生的消息系统
降低复杂度      TimescaleDB是pg扩展，不是新系统
                用最少的新技术，解决最多的问题
```

---

## 十五、部署策略：分级而不是一刀切

Feelings不能用单一的部署策略——不同服务的风险不同，策略应该不同。

### 为什么不能全蓝绿

```
全蓝绿的代价    整套生产环境翻倍
                成本太高，而且很多服务根本不需要

全蓝绿的问题    切换时有短暂中断
                用户正在接受神经刺激的那一刻断了
                感受曲线中断，这是不可接受的
```

### 分级部署策略

**Layer 3 无状态服务（API/榜单/创作者系统）**

```
策略    滚动更新（Rolling Update）
        KubePivot默认支持，make dev就能跑
理由    无状态，中断风险低，成本最低
        这类服务占Layer 3的大部分
```

**Layer 3 有状态服务（会话管理/基准计算）**

```
策略    蓝绿部署（Blue-Green）
        KubePivot的kp deploy --preview支持预览
理由    有状态服务切换失败影响大
        蓝绿保证切换时有完整的回滚能力
        但只有这部分用蓝绿，不是整个系统
```

**实时流处理（NATS + 信号处理）**

```
策略    金丝雀发布（Canary Release）
        先把5%的流量切到新版本
        观察安全数据和信号质量
        验证无问题再逐步扩大到100%
        有问题立刻回滚
理由    实时流服务影响面大
        金丝雀让问题在影响小的时候被发现
```

**设备固件更新**

```
策略    分批灰度推送（完全不同的逻辑）
        第一批：1%用户（内部测试用户）
        第二批：5%用户（早期采用者）
        第三批：20%用户
        全量：100%用户
        每批之间观察安全数据，没有问题才继续

用户控制
        用户可以选择不立即更新
        安全补丁：通知后48小时强制推送
        功能更新：用户可以延迟，不可永久拒绝

回滚机制
        设备本地保留上一个版本的固件
        回滚不需要重新下载，本地执行
```

### 成本对比

```
全蓝绿        资源成本 ×2，高
分级策略      资源成本 ×1.2-1.3，低
安全保障      分级策略不低于全蓝绿，某些场景更好
```

### KubePivot 的角色

```
kp deploy --preview    预览部署变更（支持蓝绿预览）
kp status             实时查看各服务部署状态
kp diff --drift       检测配置漂移
kp rollback           快速回滚（任何服务）
kp chaos              混沌测试（验证部署策略的可靠性）
```

KubePivot已有的能力，直接用于Feelings的部署管理。

---

神经系统是流动的系统，感受是连续的状态，不是离散的事件。

这对技术架构有一个根本性的影响：**Stream First。**

### 为什么不能用 Request/Response

```
Request/Response 模型
    用户按一下 → 系统处理 → 返回结果
    离散的，有明确的开始和结束
    适合：查询数据库、提交表单、调用API

Feelings 需要的
    设备戴上，信号就在流
    感受一直在变化，基准一直在更新
    AI教练一直在监测，不是定时检查
    这是持续的双向流，没有停顿
```

用 Request/Response 处理感受，就像用快照描述河流——你只得到了某个时刻的截面，不是流本身。

### Stream First 的具体实现

```
信号采集层（设备 → Layer 2）
    不是    每秒发送一次心率值（polling）
    而是    心率信号的持续流（streaming）
            WebSocket / gRPC bidirectional streaming
            延迟目标：<10ms

感受注入层（Layer 2 → 设备）
    不是    「开始注入」「停止注入」的离散指令
    而是    刺激参数的持续流
            实时调节强度曲线，平滑过渡
            不是阶梯式跳变，是连续的流动

个人基准更新
    不是    体验结束后批量处理
    而是    流式更新，每个信号都在实时修正基准
            增量计算，不是全量重算

AI教练感知
    不是    定时检查用户状态
    而是    持续监测信号流
            矛盾点检测是流式的，不是快照比对
            一旦出现矛盾，实时响应
```

### 延迟要求

```
感受是连续的，中断是可以被感知的

信号采集    目标 <10ms，超过50ms用户能感知到断裂
感受注入    目标 <10ms，强度变化必须平滑
矛盾点检测  目标 <100ms，检测到异常立刻响应
AI教练响应  目标 <500ms，不能让用户感到「卡了」
```

### 中医的启发

中医讲经络，讲气血的流动。气滞，是流停了。

Feelings的工作，不是「给」感受，是「调节」感受的流动——

```
疏通    帮用户接触那些从来没有流动过的感受维度
调节    在感受过强或过弱时，调节到合适的强度
维持    让流动保持连续，不被异常中断
```

就像针灸——不是在身体里放一根针产生一个效果，而是疏通经络，让气血重新流动起来。

Stream First 是这个哲学在技术层的实现。

### Go 的实现方向

```go
// 不是这样
func GetHeartRate(userID string) (int, error)

// 而是这样
func StreamHeartRate(ctx context.Context, userID string) (<-chan HeartRateSignal, error)

// 感受注入也是流
func StreamFeelingInjection(ctx context.Context, sessionID string) (chan<- InjectionParams, error)

// 四诊合参是流式处理
func StreamFourDiagnosis(ctx context.Context, signals <-chan MultiModalSignal) <-chan DiagnosisResult
```

gRPC bidirectional streaming 是 Layer 3 和 Layer 2 之间的主要通信方式。

---

Feelings 不是普通的后端服务——它的输出直接作用于人的神经系统。

单元测试验证代码逻辑，但验证不了「这个感受包真的安全」。需要一套专门的测试体系。

### 单元测试（常规）

```
覆盖范围
    感受包参数格式验证
    强度计算逻辑
    TCP解锁状态机转换
    数据库读写
    API接口契约
    安全事件记录

工具        Go testing + testify
覆盖率目标  核心逻辑 > 90%
```

### 基于行为的集成测试（Feelings特有）

**生理数据模拟层**

```
用真实采集的生理数据集回放
验证系统在不同生理状态下的判断是否符合预期

测试用例示例
    「心率120 + 皮肤电导高 + 体温正常」
    → 系统应判断为高度激活状态
    → 应触发强度限制

    「四诊矛盾：问说没事，切显示异常」
    → 矛盾点检测应识别
    → AI教练应给出对应响应
```

**感受曲线验证**

```
注入一个感受包
验证输出的神经刺激参数是否和设计的形状一致

渐强渐弱型    验证强度曲线是否呈平滑弧线
突停型        验证断裂时机和着陆保护是否正确触发
波浪型        验证周期和回落深度是否在设计范围内
```

**安全边界测试**

```
故意触发各种异常场景
    心率骤升超过阈值
    用户连续拒绝自省
    设备信号突然丢失
    强度请求超出TCP上限

验证
    系统是否在正确时机触发退避
    退避速度是否符合安全要求
    主设备掉线时从设备是否立刻停止
    fail-safe是否真的fail-safe，不是fail-open
```

**四诊合参测试**

```
构造特定场景，验证系统判断

场景一：四诊一致
    切/闻/望/问全部指向同一状态
    验证：高置信度判断，正常处理

场景二：问和切不一致
    用户说「我没事」，生理数据显示异常
    验证：矛盾点检测触发，AI教练轻提示

场景三：解离状态
    生理高度激活，但行为和语言都说平静
    验证：系统识别为解离，不是普通压制，特别处理
```

**TCP解锁路径测试**

```
模拟用户从第一次体验到成熟用户的完整路径
验证每个阶段的强度上限是否正确
验证异常事件的退避是否正确影响后续解锁进度
```

### 第一个真实测试用例

**你自己就是最重要的测试用例。**

```
第一个戴上设备的人产生的数据
是第一份真实的集成测试结果
所有的模拟数据，都是在等那一天到来之前的准备

这不是玩笑，是认真的测试策略：
创始人作为第一个用户，产生的数据有最高的信任度
因为没有人比创始人更了解设计意图
也没有人比创始人更在意安全
```

### CI/CD集成

```
每次PR
    单元测试全通过
    生理数据模拟层集成测试通过
    安全边界测试通过

每次发布
    感受曲线验证通过
    四诊合参测试通过
    TCP解锁路径测试通过

KubePivot负责部署
    kp deploy前自动跑完整测试套件
    测试不通过，部署不执行
```

---

*测试不是为了找bug，是为了在第一个用户接上设备之前，确认每一个安全边界都是真实的。*

```
KubePivot = Feelings 的 CD 基础设施

kp init --name feelings-server --module github.com/Ixecd/feelings-server
kp deploy
kp status
kp diff --drift

KubePivot 管部署，Feelings 专注感受。
地基已经在了。
```

---

## 十一、关联文档索引

```
根目录
├── Feelings-README.md          项目介绍（对外，好奇心入场券）
├── Feelings-PHILOSOPHY.md      产品哲学（12节）
├── Feelings-ROADMAP.md         路线图 + 睡眠验证指标
├── Feelings-HARD-PROBLEMS.md   硬骨头文档
├── Feelings-PASS.md            十分及格，价值观声明
├── GOVERNANCE.md               治理宪章，不可谈判红线
├── on-right-and-wrong.md       对与不对，坐标系本身没有对错
├── existence-threat-anger.md   存在性威胁触发的愤怒
└── astrology-birthchart.md     星盘分析

docs/
├── product-boundary.md         个体感受层/关系感受层/虚拟世界增强
├── device-architecture.md      设备套件设计，分工与协作协议
├── closed-loop.md              感受闭环，TCP慢启动模型
├── safety-system.md            安全体系，TCP解锁，犟种协议
├── usage-contract.md           使用契约，戴上即授权
├── contrast-protocol.md        盲选强度，反差感受设计
├── intensity-scale.md          100档对数分布，TCP解锁
├── scoring-engine.md           强度评分引擎，动态重打分
├── feeling-taxonomy.md         感受分类体系，三种检索入口
├── feeling-example-happiness.md 快乐解剖，混音结构示例
├── feeling-shapes.md           感受的七种基本形状 + 突停子类
├── feeling-naming.md           准确命名比美好更重要
├── feeling-map.md              感受地图，镜子不是任务清单
├── feeling-map-patterns.md     三种特殊模式：Kpop/游戏社交/现实实验者
├── music-system.md             音乐系统，三层架构
├── music-partnership.md        音乐平台合作，服务器AI分析
├── leaderboard-region.md       榜单与区域划分
├── introspection.md            自省系统，反依赖设计
├── temporal-system.md          时间维度，心动模式/生日/成长/状态周期
├── social-layer.md             社会传播层，多人体验
├── trauma-protocol.md          创伤协议，互补心理治疗
├── ai-coach.md                 AI教练系统（15节）
├── ai-integration.md           AI对话接入，感受过滤引擎
├── four-diagnosis.md           四诊合参，矛盾点检测
├── sleep-environment.md        睡眠环境系统
├── posture-plasticity.md       体态可塑性
├── body-sovereignty.md         身体主权，代偿机制
├── interest-guidance.md        兴趣引导，感受空白的入口
├── opportunity.md              机会就是过程
├── curiosity.md                好奇：Feelings的底层态度
├── sense-of-proportion.md      分寸感：点到为止是一种尊重
├── empathy.md                  共情：读取他人，不消融自己
├── introspection.md            自省系统
├── on-death.md                 死而无憾，逐步消除死亡恐惧
├── love-vs-hate.md             真实的爱给力量
├── love-itself-vs-feeling-loved.md 爱本身vs被爱的感觉
├── love-into-hate.md           爱到极致的恨，没有恶意的转化
├── perfectionism.md            完美主义：恐惧穿着追求的外衣
├── white-bear.md               白熊效应：不对抗，给它一个位置
├── cant-stop.md                停不下来：三种驱动与一个陷阱
├── reality-gap.md              认知与感受的落差
├── compensation-drive.md       补偿驱动：被保护的童年
├── lazy-but-trying.md          很懒，但在努力地变好
├── history-as-feeling.md       历史作为感受教科书
├── dream-journal.md            梦境记录与解析
├── intelligence.md             智力可塑性
├── intimate-feelings.md        亲密感受独立维度
├── tactile-expansion.md        触觉边界与硬件扩展路径
├── two-modes.md                增强模式vs生成模式
└── tech-architecture.md        本文档
```

---

*KubePivot 是承诺，Feelings 是立场。地基在了，开始建。*
