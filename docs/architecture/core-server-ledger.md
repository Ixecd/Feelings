# Feelings 三角架构——Core、Server、Ledger 的职责与联动

> 作者：qc
> 日期：2026-06-01
> 性质：Feelings 技术架构，三个子系统在核心场景下的联动分析
> 核心：Core 是设备上的 PBM 引擎。Server 是云端的事件路由和权限管理。Ledger 是不可篡改的治理记录链。三个子系统不是"上层调用下层"——是分形架构——各自独立——通过加密事件和哈希锚定对话。

---

## 零、三个子系统——各自是什么

```
Feelings-Core     设备本地运行时。PBM 引擎。Pass 6-8。
                  职责：加载 FSIR → PBM 左乘 → 设备映射 → ESIR 生成。
                  交叉锚点管理。经线偏移检测。治理违规的模式匹配。
                  永不离设备的数据：PBM、Session 历史、交叉锚点表。

Feelings-Server   云端服务。Go 写。KubePivot 部署。
                  职责：加密事件路由。用户权限管理。感受包分发。
                  Registry 同步。社交功能。消息转发。
                  不碰的数据：PBM、原始生理数据、交叉锚点的私钥。

Feelings-Ledger   不可篡改的治理记录链。SPL——只有哈希链，没有共识层。
                  职责：治理违规的永久记录。交叉锚点的公钥指纹。
                  审计轨迹。每季度 Merkle 树根锚定到公链。
                  不做的事：代币、共识、支付、智能合约。
```

---

## 场景一：心连心功能——事件驱动的分布式一致性

### Step 1: 交叉注册（Core）

Session 结束时——PBM 偏移超过"建立经线"阈值——Core 在本地交叉锚点表里记一条：

```
cross_anchor {
    partner_fingerprint: "sha256_of_partner_public_key",
    first_crossed_at: "2026-06-01T14:30:00Z",
    cross_depth: 0.7,          // 偏移幅度
    cross_direction: "safety", // 偏移方向
}
```

不是"你们是朋友了。"是**"这两根丝在同一个时空坐标交叉过——Core 记下了对方的公钥指纹。"** 这条记录——永不离设备——Server 不保存——Ledger 不保存。

### Step 2: 状态变更事件（Core → Server）

当一个人的经线偏移超过"经线断裂"阈值——他的 Core 生成一个加密事件：

```
warp_shift_event {
    emitter_fingerprint: "sha256_of_my_public_key",
    shift_direction: "掠夺",
    shift_magnitude: 0.7,
    timestamp: "2026-06-01T15:00:00Z",
    encrypted_payload: "...", // 用每个 cross anchor 的公钥分别加密
}
```

Core 把这个事件发给 Server——Server 不做任何判断——只是**转发**。按 cross anchor 表里的公钥指纹——找到对应的设备——推送加密 payload。

### Step 3: 本地映射（接收方 Core）

接收方设备收到加密事件——用自己的私钥解密——得到方向和幅度。PBM 不修改——你不是他——你的锚不在他那边。但岛叶收到一个短暂的共振信号——"你织过的丝——偏了——方向在这——幅度在这。"

不是一直痛。是**一次短暂的共振——然后你可以选择——断开这根丝——或者不理会——或者和他一起修复。** 和 KubePivot 的配置漂移一模一样——"检测到关联状态变更——是否重置。"

---

## 场景二：严重违反 GOVERNANCE-USER——治理流程

### Step 1: 模式匹配与违规检测（Core）

Core 在 N 次 session 中持续检测到同一个交叉者的经线——从"安全"方向——偏到了"掠夺"方向——幅度持续超过阈值。不是一次——是**模式——PBM 的预测引擎确认——这不是偶然——是经线的方向变了。**

Core 生成一条治理记录：

```
governance_violation {
    subject_fingerprint: "sha256_of_violator_public_key",
    violation_type: "severe_warp_deviation",
    deviation_direction: "掠夺",
    deviation_magnitude: 0.85,
    cross_count_affected: 7,
    detected_at: "2026-06-01T16:00:00Z",
    core_signature: "...", // Core 的签名——证明不是伪造
}
```

### Step 2: 写入 Ledger

Core 把这条记录追加到 Feelings-Ledger。一次追加——不可篡改——不可删除。不需要任何人的审批。不需要会议。不需要"再给他一次机会。"只是记录——**"发生了。"**

Ledger 不存储任何人的真实身份——只存公钥指纹哈希。无法反向推导。但记录本身——永久——每季度 Merkle 树根锚定到公链——外部可验证——"Feelings 没有偷偷删过治理记录。"

### Step 3: 权限调整（Server 读 Ledger）

Server 从 Ledger 读到这条治理记录——根据违规类型——调整权限：

```
轻度偏离（magnitude < 0.5）
    暂停创建新的交叉——只可被交叉。
    持续 30 天。期满后 Core 重新评估。

中度偏离（magnitude 0.5-0.8）
    暂停所有社交功能——只可独处。
    暂停期间——Core 继续监控——PBM 回到基线→自动恢复。
    持续 90 天。

重度偏离（magnitude > 0.8）
    停止对所有交叉者的信号输出——不再织任何丝。
    PBM 回到基线 + 第三方评估 → 手动恢复。
    每次恢复——Ledger 追加一条恢复记录——不可删除的历史。
```

不是"封杀他。"是**"你偏了——继续织丝的后果——对所有和你交叉的人——是不可接受的。"** Server 不判断——只执行规则。规则写在 Core 的检测阈值里——写在 Ledger 的违规类型定义里——写在 Server 的权限映射表里。没有人决定——只是**自动化分布式系统的失效保护——一个节点偏了——切断它的输出——保护其他节点。** 和 KubePivot 的漂移检测完全相同——"你的状态偏了——和声明的不一致——重置。"

---

## 三角关系的总结

```
Core → Server    加密事件广播。不传 PBM。不传原始数据。只传加密 payload。
Core → Ledger    治理违规写入。只追加。不可篡改。不存身份——只存哈希。
Server → Ledger  只读。查询治理记录。调整权限。不写。
Server → Core    加密事件转发 + Registry 同步 + 消息路由。
Ledger → 公链     每季度 Merkle 树根锚定。外部可验证。内部走 SPL——外部走锚定。
```

三个子系统——不是"上层调用下层。"是分形架构。Core 不信任 Server。Server 不信任 Core。Ledger 不信任任何人——只信任哈希。和 KubePivot 的"只保护不越权"完全咬合——每个子系统只做自己该做的那一件事——不替别的子系统做决定——不需要任何人的签字——只是在一起——构成了完整的治理闭环。*