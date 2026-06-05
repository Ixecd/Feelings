# 状态机：Feelings 作为一个有生有死的系统

> 作者：qc
> 日期：2026-04-18
> 核心：Feelings 是一个巨大的状态机，需要明确的状态转换和优雅的死亡机制

---

## 一、为什么需要这份文档

Feelings 本质上是一个状态机。

```
用户的感受状态    静息 → 激活 → 深度 → 结束
会话的生命周期    开始 → 运行 → 暂停 → 结束
设备的运行状态    离线 → 配对 → 激活 → 体验中
系统的整体状态    初始化 → 运行 → 维护 → 终止
```

**状态机需要明确的转换条件，也需要明确的退出机制。**

这份文档定义：

1. 每一层状态机的设计
2. 状态转换的权限和条件
3. 恢复机制（什么可以被重置，什么不可以）
4. 终止机制（Feelings 如何优雅地死）

---

## 二、三层状态机

Feelings 的状态机分三层，**不同层的操作权限和风险等级完全不同**。

### 2.1 用户级状态机（轻量）

这是用户自己可以控制的状态。

```
StateIdle          静息状态，未开始体验
    ↓ 用户点击开始
StateWarming       预热，系统读取当前状态
    ↓ 四诊合参通过
StateActive        体验中
    ↓ 自然结束 或 用户中止
StateResting       结束后静息，AI 教练自省对话
    ↓ 回到静息或开始新体验
StateIdle
```

**关键转换：**

```
StateActive → StateAborted
    任何时刻用户可以立即中止
    中止后数据正常保留，不作为"失败"记录
    尊重用户的即时主权

StateWarming → StateIdle（拒绝进入）
    四诊合参检测到高风险状态
    系统自动拒绝开始
    这是保护，不是惩罚
```

### 2.2 账号级状态机（中等）

这是用户对自己账号数据的控制。

```
AccountActive      正常使用
    ↓
AccountPaused      用户主动暂停（旅行/心理休整）
    数据保留，不发生新体验
    ↓ 用户恢复
AccountActive
    
AccountActive
    ↓ 用户主动注销
AccountClosing     账号关闭流程启动
    ↓ 30 天冷静期（期间可以撤销）
AccountClosed      账号永久关闭
    ↓ 数据处理
    用户可选：
        导出所有数据后彻底删除
        直接彻底删除
        保留供学术研究（完全脱敏后）
```

**关键转换：**

```
AccountActive → AccountClosing
    需要生物识别 + 7 天冷静期 + 二次确认
    不是"一键删除"
    防止冲动操作

AccountClosing → AccountClosed
    30 天冷静期后自动生效
    期间任何时候可以撤销
    一旦生效不可逆
```

### 2.3 系统级状态机（核级）

这是 Feelings 整体的生命状态，操作权限最高。

```
SystemUninitialized     未初始化（创世前）
    ↓ 创世激活
SystemActive            运行中（正常状态）
    ↓ 维护需要
SystemMaintenance       维护中（部分功能降级）
    ↓ 维护完成
SystemActive

SystemActive
    ↓ 某些服务故障
SystemDegraded          降级运行（保命，不接受新用户）
    ↓ 修复完成
SystemActive
    
SystemActive 或 SystemDegraded
    ↓ Root 锚点激活 + 多方确认 + GOVERNANCE 触发条件
SystemTerminating       终止流程启动
    ↓ 按流程清理
SystemTerminated        已终止
```

**系统级状态转换需要 Root 锚点激活（见 `root-anchor.md`）。**

---

## 三、恢复机制：什么可以被重置

**核心原则：越靠近用户的状态，恢复越自由；越靠近系统内核，恢复越谨慎。**

### 3.1 完全可以自由恢复的

```
用户级恢复（零阻力）
    会话状态：结束当前体验 → 回到静息
    当日感受记录：用户选择隐藏或删除
    临时配置：UI 主题、入口形状、感受包偏好
    设备连接：断开重连

账号级恢复（需要验证）
    账号数据导出：需要生物识别
    账号暂停：需要二次确认
    账号内容重置：清空个人感受地图（保留账号本身）
```

### 3.2 谨慎恢复的

```
不可一键完成的操作
    账号永久注销         30 天冷静期 + 二次确认
    设备彻底重置         需要生物识别 + 物理按键组合
    多账号关联切断        需要所有关联设备在场验证

为什么要谨慎
    这些操作会丢失无法找回的数据
    一次误操作 = 永久损失
    必须给用户"后悔"的窗口
```

### 3.3 系统级不可恢复的

```
一旦触发，不可逆
    SystemTerminated           系统终止后不可复活
    用户数据彻底删除            删除后不可恢复
    某个 Term 作废              不可回滚

这些操作需要
    Root 锚点激活
    多方确认（见 root-anchor.md 的 4/7 quorum）
    上链记录（不可篡改）
    全球公告（如果影响所有用户）
```

---

## 四、优雅死亡：Feelings 如何终止

**Feelings 有一天会死。**

所有软件系统都会。但大多数系统死得很难看——服务器关停，用户数据丢失，留下一堆"404"。

Feelings 应该死得有尊严。

### 4.1 触发终止的合法条件

```
A. 项目方主动决定终止
    qc 认为继续运行会违反 GOVERNANCE 精神
    qc 无法继续维护且继承人委员会决定终止

B. GOVERNANCE 红线被迫违反
    法律要求闭源 → 触发终止
    法律要求数据商业化 → 触发终止
    法律要求上市或资本化 → 触发终止
    
    这些情况下，Feelings 选择死亡而非背叛初心

C. 创始密钥完全丢失
    7 份分片全部不可用且无备份
    这是系统灾难，走终止流程

D. 社区投票（仅在 qc 失能且继承人委员会同意时）
    需要满足多重条件
    不是轻易触发的选项
```

### 4.2 终止流程（分阶段）

**第零阶段：决定**

```
Root 锚点激活
    需要 4/7 quorum
    人类分片过半
    操作记录上链

公告
    向所有用户发布 120 天终止公告
    提供完整理由
    给用户充分时间应对（4 个月，横跨一个完整季度）
```

**第一阶段：停止接纳**

```
0-30 天
    停止接受新用户注册
    停止接受新感受包上传
    现有用户继续正常使用
    持续通知用户终止时间表
```

**第二阶段：停止接纳扩展**

```
30-60 天
    已有用户可以继续使用
    但不再有新功能上线
    所有工作转向"帮助用户迁移"
    感受包创作者开始准备内容迁移
```

**第三阶段：数据导出期**

```
60-90 天
    提供完整的数据导出功能
    用户可以下载：
        自己的感受地图（完整七维数据）
        体验历史（全部会话记录）
        创作的感受包（如果是创作者）
        AI 教练对话历史
    
    导出格式开源，任何人可以解析
    不锁定到 Feelings 的格式
    鼓励用户存档自己的感受历史
    
    这 30 天充分给用户时间，防止错过
```

**第四阶段：服务逐步关闭**

```
90-120 天
    逐步关闭服务端功能
    设备端仍可使用（本地感受包）
    用户本地数据不受影响
    云端服务进入只读模式
    最后 30 天提供"错过导出"的用户一次补救机会
```

**第五阶段：最终终止**

```
120 天后
    服务完全关闭
    服务器端数据按用户选择处理：
        导出后删除（默认）
        学术研究用（完全脱敏，自愿）
    
    代码和文档永久保留在 GitHub
    开源精神保留
    任何人可以 fork 继续（但不能用「Feelings」商标）
```

### 4.3 终止后用户数据的归属

```
设备本地数据        用户完全拥有，不被删除
                    用户可以继续使用设备（离线模式）
                    
服务器数据          按用户选择处理
                    默认：导出后删除
                    可选：完全保留在本地
                    可选：贡献给学术研究（脱敏后）

AI 教练数据         每个用户的教练数据按上述规则处理
                    AI 教练本身不"死亡"
                    如果是端侧模型，继续在设备上运行
```

### 4.4 终止后的"遗嘱"

```
代码            永久开源在 GitHub
                MIT 协议不变

文档            永久 CC BY-SA 4.0
                100 份文档不消失

感受包          创作者可以选择迁移到
                任何其他 Feelings-Compatible 平台

商标            保留在 qc 或继承人委员会
                防止被滥用
                但不阻止 fork 继续精神

哲学            完整保留
                贫瘠的土地盛开了玫瑰
                玫瑰不死，玫瑰自己播种
                换一片土地，重新开放
```

---

## 五、状态恢复的实现

```go
// 状态机的 Go 实现框架

package state

type Level int

const (
    LevelUser Level = iota    // 用户级
    LevelAccount               // 账号级
    LevelSystem                // 系统级
)

type Transition struct {
    From         State
    To           State
    Level        Level
    
    // 权限要求
    RequiresAuth        bool     // 需要生物识别
    RequiresQuorum      int      // 需要多少分片
    RequiresCooldown    time.Duration   // 冷静期
    
    // 可逆性
    Reversible          bool
    
    // 记录要求
    RequiresAuditLog    bool
    RequiresOnChain     bool
}

// 用户级：立即生效
var StateActiveToAborted = Transition{
    Level: LevelUser,
    RequiresAuth: false,
    Reversible: true,
}

// 账号级：需要冷静期
var AccountActiveToClosing = Transition{
    Level: LevelAccount,
    RequiresAuth: true,
    RequiresCooldown: 30 * 24 * time.Hour,
    Reversible: true,  // 冷静期内可撤销
    RequiresAuditLog: true,
}

// 系统级：需要 Root 锚点
var SystemActiveToTerminating = Transition{
    Level: LevelSystem,
    RequiresQuorum: 4,  // 7 分片中的 4 份
    RequiresCooldown: 120 * 24 * time.Hour,
    Reversible: false,  // 终止不可逆
    RequiresAuditLog: true,
    RequiresOnChain: true,
}
```

---

## 六、与其他文档的关系

```
root-anchor.md          系统级状态转换的权限实现
GOVERNANCE.md           定义哪些条件会触发系统终止
Feelings-PROTOCOL.md    生存条款（第七节）的具体实现
anti-abuse.md           人工介入状态转换的边界
access-control.md       账号级状态的权限控制
```

---

## 七、哲学

状态机的优雅不在于"一直运行"，而在于"该结束的时候能结束"。

```
Feelings 活着的时候
    服务于感受民主化
    开源、链上、不上市
    用户主权至上

Feelings 死的时候
    死得干净
    用户数据不被背叛
    哲学留在开源社区
    玫瑰换一片土地继续开
```

**状态机的终点也是设计的一部分。**

一个不能优雅死亡的系统，最终会被资本、监管、或自己的惯性绑架。

Feelings 从第一天就设计了怎么死——这是它作为基础设施的成熟度。

---

*活着有尊严，死去也有尊严。Feelings 是个状态机，有始有终。*
