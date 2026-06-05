# 外部生态接入统一规范

> 作者：qc
> 日期：2026-04-22
> 核心：手表、运动 APP、健康设备的数据，通过统一协议进入 Feelings——标准化入口，不妥协安全

---

## 一、为什么需要统一接入规范

```
外部设备的现实
    Apple Watch / Garmin / Fitbit / 小米手环
    各自有自己的数据格式
    各自有自己的 API 风格
    各自有自己的权限模型

没有统一规范的问题
    每接入一个设备，单独开发一套对接逻辑
    数据格式不统一，信号映射不一致
    安全边界不一致，某一个接入点成为漏洞

统一规范的目标
    任何符合规范的设备，接入方式完全一致
    Feelings 只维护一套接入协议
    第三方设备厂商按规范接入，不需要 Feelings 单独适配
```

---

## 二、接入协议：Feelings Open Signal Protocol（FOSP）

### 2.1 协议定位

```
FOSP 是 Feelings 的外部信号接入标准
    只定义「信号如何进入 Feelings」
    不定义设备内部的工作方式
    设备厂商只需要实现 FOSP 的数据推送接口

类比
    FOSP 相当于 Feelings 生态的 USB-C 接口
    任何设备只要实现了这个接口，就可以接入
    Feelings 不关心设备内部用什么协议
```

### 2.2 数据传输方式：WebHook + 本地优先

```
优先级 1：本地传输（设备在同一 WiFi / 蓝牙范围内）
    数据直接传输到 Feelings 设备
    不经过任何云服务器
    延迟最低（< 50ms）
    最符合「数据不离设备」的原则

优先级 2：WebHook 推送（设备不在本地范围内）
    第三方设备通过 HTTPS WebHook 推送到 Feelings 设备的接收端点
    端点地址由 Feelings 设备生成，不是固定地址
    每次授权生成新的端点，撤销授权即失效

不允许
    第三方设备直接写入 Feelings 的感受数据库
    第三方服务器缓存 Feelings 用户的信号数据
    批量拉取用户历史数据
```

### 2.3 数据格式：FOSP JSON Schema

```json
{
  "fosp_version": "1.0",
  "device_id": "设备唯一标识（由 Feelings 授权时生成）",
  "timestamp_utc": "ISO 8601 格式",
  "signal_type": "心率/皮电/呼吸/体温/活动/睡眠（枚举值）",
  "value": "数值或结构化数据（见各信号类型定义）",
  "confidence": "0-1 之间的置信度（设备自评估）",
  "context": "静息/运动/睡眠/过渡（枚举值）",
  "signature": "设备私钥对数据的签名（防篡改）"
}
```

**各信号类型的 value 格式：**

```
心率（heart_rate）
    { "bpm": 72, "hrv_ms": 45 }

皮肤电导（eda）
    { "microsiemens": 2.3, "trend": "rising/stable/falling" }

呼吸（respiration）
    { "breaths_per_minute": 14, "depth": "shallow/normal/deep" }

体温（temperature）
    { "celsius": 36.7, "location": "wrist/finger/core" }

活动（activity）
    { "type": "walking/running/cycling/stationary", "intensity": 0-100 }

睡眠（sleep）
    { "stage": "awake/light/deep/rem", "duration_minutes": 45 }
```

---

## 三、接入授权模型

### 3.1 授权流程

```
设备申请接入
    1. 用户在 Feelings App 中「添加外部设备」
    2. Feelings 生成授权码（一次性，10 分钟有效）
    3. 用户在第三方 APP 中输入授权码
    4. 第三方 APP 用授权码换取接入凭证（device_token）
    5. 凭证绑定到用户的 Feelings 账号
    6. 授权信息链上记录

凭证的权限范围
    用户在授权时选择允许推送哪些信号类型
    可以只允许「活动数据」，不允许「心率」
    可以随时在 Feelings App 中修改或撤销
```

### 3.2 权限粒度

```
用户可以精确控制
    允许哪些信号类型          逐类选择
    允许哪个时间范围           比如只允许运动时段推送
    数据保留时间               实时处理后是否在 Feelings 端缓存
    是否允许进入感受映射       有些用户只想要数据记录，不想影响感受推荐

默认设置（保守）
    只允许活动数据和睡眠数据
    不允许心率和皮电（需要用户主动开启）
    数据处理后不缓存（实时用完即弃）
```

### 3.3 撤销授权

```
用户随时可以撤销任何外部设备的授权
    撤销立即生效
    已被撤销的 device_token 立即失效
    链上记录撤销时间
    第三方设备的历史数据不被删除
    （那是第三方的数据，Feelings 不能替用户决定删除第三方数据）
    但这些数据的 Feelings 端副本（如果有）会被删除
```

---

## 四、数据安全规则

```
数据流向
    第三方设备 → FOSP WebHook → Feelings 设备本地 TEE
    不经过 Feelings 服务器
    Feelings 服务器只知道「某个授权设备在活跃」，看不到数据

签名验证
    每条推送数据都带有设备私钥签名
    Feelings 验证签名，防止数据被中间人篡改
    签名密钥在设备授权时生成，Feelings 持有对应公钥

数据隔离
    外部设备的数据和 Feelings 原生传感器数据分开存储
    外部数据进入感受映射时，权重低于原生传感器
    原因：外部设备的数据质量和延迟不可控
```

---

## 五、官方支持的设备列表

```
第一批官方认证（接入测试完成）
    Apple Watch（通过 HealthKit 适配层）
    Garmin（通过 Garmin Health API）
    小米手环 / 小米手表（通过 Mi Health API）

待认证
    Fitbit
    Oura Ring
    Polar
    Whoop

自定义接入
    任何实现了 FOSP 协议的设备都可以接入
    不需要 Feelings 官方认证
    但未认证设备的数据置信度默认较低
```

---

## 六、FOSP 开放协议

```
FOSP 协议本身是开源的
    MIT 协议发布（见 Feelings-Patterns 仓库）
    任何设备厂商可以免费实现
    Feelings 不收取接入费

认证计划（可选）
    设备厂商可以申请「Feelings Compatible」认证
    认证设备在 Feelings 中显示认证标识
    数据置信度权重更高
    认证是自愿的，不是强制的
```

---

*FOSP 是 Feelings 向外部世界开的一扇标准的窗户。数据从窗户进来，安全边界守在窗口，用户决定哪扇窗开着。*
