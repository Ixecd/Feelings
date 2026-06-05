# Webhook：感受世界的开放接口

> 作者：qc
> 日期：2026-04-13
> 核心：Feelings不是孤岛，感受事件可以触发世界，世界也可以触发感受

---

## 一、为什么需要 Webhook

```
没有 Webhook    Feelings 是一个孤岛
                感受体验发生了，外部系统不知道
                外部世界发生了，Feelings 不知道

有 Webhook      Feelings 成为感受层的基础设施
                任何系统可以订阅感受事件
                任何系统可以触发感受响应
                生态真正打开
```

---

## 二、出站 Webhook（Feelings → 外部）

Feelings 向外部系统发送感受事件。

### 感受体验层

```
session.started         体验开始
    { user_id, pattern_id, mode, started_at }

session.ended           体验结束
    { user_id, pattern_id, duration, intensity_reached }

session.interrupted     体验中断（安全退避/用户主动停止）
    { user_id, reason, occurred_at }

safety.event            安全事件触发
    { user_id, level, action_taken, occurred_at }
    → 监护人系统/治疗师系统实时收到通知

baseline.milestone      感受强度突破历史最高
    { user_id, dimension, new_ceiling, previous_ceiling }

feeling_map.updated     感受地图新坐标
    { user_id, new_coordinates, updated_at }
    → 成长追踪系统
```

### 创作者层

```
pattern.used            感受包被使用
    { pattern_id, creator_id, usage_count_today }
    → 创作者的数据分析系统

revenue.earned          收益到账
    { creator_id, amount, pattern_id, tx_hash }
    → 财务系统/链上系统

pattern.reported        感受包被举报
    { pattern_id, report_count, reason }
    → 创作者通知系统

pattern.reviewed        审核结果
    { pattern_id, result, reviewer_note }
```

### 社交层

```
social.invitation       收到多人体验邀请
    { from_user, pattern_id, session_id }

social.comment          感受包收到评论
    { pattern_id, commenter_id, created_at }

social.joined           有人加入多人体验
    { session_id, user_id }
```

### 守护者层

```
guardian.alert          监护用户异常状态
    { user_id, alert_type, severity, occurred_at }
    → 监护人紧急通知

guardian.offline        设备离线超过阈值
    { user_id, offline_duration, last_seen }

guardian.sos            用户触发SOS
    { user_id, location_available, occurred_at }
    → 立刻通知所有紧急联系人
```

---

## 三、入站 Webhook（外部 → Feelings）

外部系统触发 Feelings 的感受响应。

这是把 Feelings 变成感受层基础设施的关键。

### 运动与健康

```
POST /webhooks/inbound/activity

Nike Run Club 完成一次长跑
    → Feelings 自动进入「运动后增强模式」
    → 放大「突破身体极限之后」的感受

Apple Health 检测到用户心率异常
    → Feelings 暂停正在进行的感受体验
    → 通知用户先关注身体状态

Oura Ring 显示深睡不足
    → Feelings 次日推荐睡眠类感受包
    → 调低当天推荐的感受包强度
```

### 日历与时间

```
POST /webhooks/inbound/calendar

用户日历显示今天是重要日子（生日/纪念日/重要事件）
    → Feelings 发送特殊的感受包
    → AI 教练在今天特别在意这个用户的状态

用户设置的「感受时间」到了
    → Feelings 发送提醒
    → 准备好当天的推荐感受包
```

### 创作与工作

```
POST /webhooks/inbound/productivity

用户在 GitHub 合并了一个重要 PR
    → Feelings 推荐「完成一件难事之后」的感受包
    → 帮用户把那个成就感真正落地

用户在日历里标记了「完成了X目标」
    → Feelings 触发成长轨迹更新
    → AI 教练发送一条有意义的确认
```

### 环境感知

```
POST /webhooks/inbound/environment

天气 API 显示今天是用户所在地的第一场雪
    → Feelings 推荐和季节感受相关的感受包

用户进入了某个地点（博物馆/音乐厅）
    → Feelings 自动进入「历史感受增强模式」
    → 帮用户把那个场景的感受真正落地
```

---

## 四、Webhook 安全设计

Webhook 有一个特殊的安全风险——事件数据会发送到第三方系统。

### Payload 原则：只有元数据

```
✅ 正确
    { "event": "session_ended", "duration": 1200, "pattern_id": "xxx" }

❌ 错误
    { "event": "session_ended", "heart_rate_data": [...], "eeg_data": [...] }
```

**Webhook payload 永远不包含原始生理数据。**

只有「发生了什么」，不包含「数据是什么」。

### 签名验证

```
每个 Webhook 请求带有 HMAC-SHA256 签名
    X-Feelings-Signature: sha256=xxx

接收方验证签名
    防止伪造的 Webhook 请求
    防止中间人篡改

密钥管理
    每个订阅者有独立的签名密钥
    密钥可以随时轮换
    轮换期间新旧密钥都有效（过渡期24小时）
```

### 重试机制

```
交付失败时
    立刻重试一次
    1分钟后重试
    5分钟后重试
    30分钟后重试
    最多重试5次

超过重试次数
    事件进入死信队列
    订阅者可以手动重新触发
    系统记录失败原因
```

### 订阅者管理

```
订阅者注册
    提供回调 URL
    选择订阅的事件类型
    设置过滤条件（只接收特定用户/特定模式的事件）

权限控制
    订阅者只能订阅自己有权访问的事件类型
    创作者只能订阅自己感受包相关的事件
    监护人只能订阅被监护用户的事件

用户授权
    入站 Webhook 需要用户明确授权
    「允许 Nike Run Club 向 Feelings 发送运动数据」
    用户可以随时撤销任何外部系统的授权
```

---

## 五、技术实现

```
语言        Go（和 feelings-server 同一个仓库）
队列        NATS JetStream（保证交付，持久化）
存储        PostgreSQL（订阅者配置 + 事件日志）
重试        NATS 内置重试机制

出站流程
    感受事件发生
        ↓
    发布到 NATS topic
        ↓
    Webhook Worker 消费
        ↓
    查找订阅者列表
        ↓
    并发发送（每个订阅者独立）
        ↓
    记录结果（成功/失败/重试）

入站流程
    外部系统 POST /webhooks/inbound/{type}
        ↓
    验证来源（OAuth token）
        ↓
    验证用户授权
        ↓
    解析事件
        ↓
    发布到内部 NATS topic
        ↓
    对应的感受服务消费处理
```

---

## 六、和 Stream First 的关系

Webhook 是 Stream First 架构的外部延伸——

```
内部        信号流、感受流（gRPC streaming）
外部        感受事件流（Webhook + NATS）

不是两套不同的系统
而是同一个流动的感受世界
向内，是神经系统的信号流
向外，是生活事件的感受流
```

Feelings 最终想成为的：

**感受层的基础设施，让整个世界的事件都可以在感受层留下印记。**

---

*感受不是孤立发生的，生活的每一个时刻都可以是感受的入口。Webhook 是那扇门。*
