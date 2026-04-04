# Feelings 技术架构

> 作者：qc
> 日期：2026-04-04
> 状态：早期设计，持续演进

---

## 一、架构全景

Feelings 是一个感受民主化平台，技术上需要跨越从硬件到云端的完整栈。

```
用户
  ↓
客户端（移动端 / Web）
  ↓
Layer 3：应用服务层        ← Go 主场，现阶段重点
  ↓
Layer 2：信号处理层        ← Python（研究）→ C++/Rust（产品）
  ↓
Layer 1：硬件 / 固件层     ← C/C++，实时操作系统
  ↓
神经接口硬件
```

每一层职责清晰，技术选型不同，但边界明确——上层不需要知道下层的实现细节。

---

## 二、Layer 1：硬件 / 固件层

**职责**：直接操控神经接口硬件，采集和输出神经信号。

**技术选型**：
- 语言：C / C++ / Rust
- 运行时：实时操作系统（FreeRTOS 或类似）
- 通信：蓝牙 BLE / 有线接口

**核心要求**：
- 实时性：微秒级响应，不能有任何不可预期的延迟
- 安全性：直接作用于人体，故障模式必须是安全的
- 低功耗：可穿戴设备的电池限制

**当前状态**：研究阶段，硬件形态未定。

---

## 三、Layer 2：信号处理层

**职责**：将原始神经信号转化为"感受模式"，将"感受配置"转化为神经刺激参数。

**为什么不用 Go**：

Go 的 GC 哪怕停顿 < 1ms，在实时神经信号处理里也是不可接受的。信号处理需要：
- 大量矩阵运算（NumPy/BLAS 级别）
- GPU 加速推理（CUDA 生态）
- 严格的实时性保证（无 GC 停顿）

**技术选型**：
```
研究阶段：Python + NumPy / SciPy / PyTorch
          → 神经科学领域的事实标准，生态最完整
          
产品阶段：C++ / Rust
          → 性能确定性，无 GC，可嵌入固件
          
推理加速：ONNX Runtime / TensorRT
          → 将 Python 训练的模型导出，在 C++ 里推理
```

**核心问题（待研究）**：
- 如何采集"已知感受"对应的神经信号模式？
- 如何验证注入的信号产生了预期的感受？
- 个体差异有多大？模型需要个性化吗？

---

## 四、Layer 3：应用服务层

**职责**：用户系统、设备管理、感受配置编排、数据存储、计费。

**这是当前阶段的重点，也是 Go 的主场。**

**技术选型**：
```
语言：Go
数据库：PostgreSQL（业务数据）+ etcd（分布式状态）
部署：KubePivot（CD 基础设施已就绪）
```

**核心模块**：

```
feelings-server/
├── cmd/feelings/          # 服务入口
├── internal/
│   ├── api/               # HTTP API（设备注册、感受配置、用户管理）
│   ├── device/            # 设备状态管理（在线/离线/固件版本）
│   ├── session/           # 感受会话（开始/暂停/结束/历史）
│   ├── pattern/           # 感受模式库（存储和检索）
│   ├── user/              # 用户系统（认证/权限/订阅）
│   └── billing/           # 计费（感受消费记录）
├── migrations/            # PostgreSQL 迁移
└── configs/               # KubePivot 部署配置
```

**数据模型（初稿）**：

```sql
-- 感受模式（Layer 2 生成，Layer 3 存储）
CREATE TABLE feeling_patterns (
    id          UUID PRIMARY KEY,
    name        TEXT NOT NULL,        -- "专注"/"平静"/"成就感"
    description TEXT,
    category    TEXT,                 -- "个体"/"关系/竞争"/"关系/合作"
    signal_config JSONB,              -- 下发给 Layer 2 的参数
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 感受会话（用户实际体验记录）
CREATE TABLE feeling_sessions (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    device_id   UUID NOT NULL,
    pattern_id  UUID NOT NULL,
    started_at  TIMESTAMPTZ,
    ended_at    TIMESTAMPTZ,
    feedback    JSONB,               -- 用户事后反馈
    intensity   INT                  -- 1-10，感受强度主观评分
);

-- 设备注册
CREATE TABLE devices (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    hardware_id TEXT UNIQUE,
    firmware_version TEXT,
    status      TEXT DEFAULT 'offline',
    last_seen   TIMESTAMPTZ
);
```

---

## 五、Layer 4：客户端层

**职责**：用户交互界面，设备配套 App。

**技术选型**：
```
移动端：Swift（iOS）/ Kotlin（Android）
        → 神经接口设备大概率先做 iOS（Apple 的神经接口布局）
Web 端：TypeScript + React
        → 配置管理、数据可视化、开发者工具
```

**当前状态**：未启动，等 Layer 3 API 稳定后再做。

---

## 六、两层产品架构的技术映射

来自 `docs/product-boundary.md` 的设计决策在技术层的体现：

```
Layer 1（个体感受，神经直接注入）
  技术路径：Layer 1 硬件 → Layer 2 信号处理 → 直接输出刺激
  用户交互：选择感受模式 → 设备执行 → 记录反馈

Layer 2（关系感受，现实增强）
  技术路径：Layer 3 会话管理 → 多设备同步 → 实时增强
  用户交互：多人同时开启会话 → Feelings 协调增强同一个真实场景
```

多人会话的技术挑战：
- 多设备实时同步（WebSocket + etcd）
- 感受的"共鸣"算法（两个人同时体验同一场景时，如何协调各自的增强参数）

---

## 七、数据隐私与安全

神经数据是最敏感的个人数据，比医疗数据更私密。

**基本原则**：
- 原始神经信号**永远不离开设备**——Layer 2 在本地运行，只有感受模式的元数据上传
- 感受会话记录**用户可以完全删除**
- 感受模式库**用户拥有所有权**，可以导出

**这不只是合规要求，是产品的核心承诺。**

---

## 八、当前阶段重点

```
现在：
  ✅ 产品边界清晰（docs/product-boundary.md）
  ✅ 技术架构确定
  ⬜ Layer 3 第一版 API 设计
  ⬜ feelings-server 仓库初始化（kp init）
  ⬜ 基础数据模型实现

下一步：
  ⬜ Layer 2 研究：找到第一个可以采集和复现的简单感受模式
  ⬜ 硬件选型：从现有非侵入式神经接口设备开始（EEG 头环）
  ⬜ 第一个 demo：用 EEG 采集"专注"状态，尝试在另一个人身上复现

最终目标：
  "让每个人都能体验到不同的感受"
  感受这件事，对每个人都公平。
```

---

## 九、和 KubePivot 的关系

```
KubePivot = Feelings 的 CD 基础设施

当 feelings-server 需要部署时：
  kp init --name feelings-server --module github.com/Ixecd/feelings-server
  kp deploy
  kp status
  kp diff --drift

KubePivot 管部署，Feelings 专注感受。
地基已经在了。
```
