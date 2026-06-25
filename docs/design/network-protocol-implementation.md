# 网络协议设计：v0.x 落地实施

> 性质：设计文档
> 日期：2026-06-25
> 前置阅读：docs/architecture/network-protocol.md（QUIC 理论选型）
> 核心：v0.x 原型期走 HTTP/2 + WebSocket 快速打通；v1.0 切 QUIC 对用户无感知

---

## 〇、先定前提

```
v0.x = 打通端到端数据流，验证感受闭环，不优化极致延迟
v1.0 = QUIC 全栈切换，目标 <10ms 设备→边缘
```

这个文档不重复 `network-protocol.md` 的 QUIC 论证——它写 v0.x 怎么做、v1.0 怎么切、中间不返工。

> 性质：实施设计，不是选型综述
> 核心：三层协议的每层具体选择 + 数据格式 + 安全 + Rust crate 清单

---

## 一、三层网络架构

```
┌─────────────────────────────────────────────────────────┐
│ Layer 0: 设备层                                          │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐                 │
│ │耳后 iCE40 │ │后颈 GW1N  │ │腕部 PPG  │  BLE mesh 本地  │
│ │ 采集+喷帧 │ │ 帧引擎   │ │ 传感器   │  组网，不经过IP  │
│ └────┬─────┘ └────┬─────┘ └──────────┘                 │
│      │ UART 460800 │                                     │
│      │ 9B framed   │                                     │
│      ▼             ▼                                     │
├─────────────────────────────────────────────────────────┤
│ Layer 1: 边缘处理单元（本地主机 / 手机 / Pi）             │
│ ┌──────────────────────────────────┐                    │
│ │ feelingsd (Rust daemon)          │                    │
│ │  ├─ serial reader (UART → FSIR)  │                    │
│ │  ├─ PBM 本地持久化               │                    │
│ │  ├─ SessionManager 本地          │                    │
│ │  └─ WebSocket client → server    │                    │
│ └──────────────────────────────────┘                    │
│      │ WebSocket over TLS (WSS)                          │
│      │ wss://feelings.server/v1/stream                  │
├─────────────────────────────────────────────────────────┤
│ Layer 2: 服务器                                         │
│ ┌──────────────────────────────────┐                    │
│ │ feelings-server (Rust)           │                    │
│ │  ├─ WSS acceptor (axum)          │                    │
│ │  ├─ Session router               │                    │
│ │  ├─ PBM store (db)               │                    │
│ │  └─ stream → Coach AI            │                    │
│ └──────────┬───────────────────────┘                    │
│            │ WSS                                          │
├────────────▼────────────────────────────────────────────┤
│ Layer 3: 客户端                                          │
│ ┌──────────────────────────────────┐                    │
│ │ Web Dashboard / Mobile App       │                    │
│ │  ├─ 实时感受地图 WSS             │                    │
│ │  ├─ 自省报告 REST                │                    │
│ │  └─ 会话回放 REST                │                    │
│ └──────────────────────────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

**关键决策**：Layer 0 不经过 IP——iCE40 到 GW1N 就是三根飞线 + UART 460800。空中协议是 v1.0 的事（BLE mesh / 无线 GSR 贴片）。

---

## 二、v0.x 协议选择——每层具体决定

### 2.1 Layer 1→2: 边缘 → 服务器

| 选项 | 选择 | 理由 |
|---|---|---|
| 传输 | **WebSocket over TLS** | 全双工，单连接多流模拟，浏览器原生支持 |
| 协议 | **自定义二进制帧**（见 §三） | 不用 protobuf——感受数据高频小包，protobuf 序列化开销不值得 |
| WebSocket 库 | **tokio-tungstenite** | 纯 Rust，tokio 生态，生产级 |
| TLS | **rustls** | 纯 Rust，无 OpenSSL 依赖 |
| HTTP 框架 | **axum** | 轻量，tower 中间件生态，WebSocket 升级原生支持 |

**为什么不用 gRPC-web**：gRPC 的 binary framing 对浏览器不够原生（需要 grpc-web proxy），对 v0.x 是额外复杂度。WebSocket 直接升级 HTTP 连接，零额外代理。

### 2.2 Layer 1 内部: 设备 → 边缘

| 选项 | 选择 | 理由 |
|---|---|---|
| 物理层 | **UART 460800 baud** | iCE40 硬件决定，9 字节帧 + XOR Checksum |
| 边缘接收 | **tokio-serial** | 跨平台串口读取，tokio 异步 |
| 帧解析 | **FSIR parser（Rust 实现）** | 在 feelingsd 内完成 FSIR→PSIR 初始转换 |

### 2.3 Layer 2→3: 服务器 → 客户端

| 选项 | 选择 | 理由 |
|---|---|---|
| 实时推送 | **WebSocket (WSS)** | 同一条 WSS 连接承载多流 |
| REST | **axum JSON API** | 自省报告、会话历史、配置——不需要实时 |
| 认证 | **Bearer token (JWT)** | 标准方案，axum 生态成熟 |

### 2.4 v1.0 QUIC 切换路径

```
v0.x:
  边缘 ──WSS──▶ 服务器 ──WSS──▶ 客户端
  tokio-tungstenite   axum-ws

v1.0:
  边缘 ──QUIC──▶ 服务器 ──QUIC──▶ 客户端
  quinn              quinn + tonic(grpc)
```

**不返工的保证**：v0.x 的二进制帧格式（§三）和 QUIC 的流模型天然对齐。切换只改传输层，不改帧格式和业务逻辑。

---

## 三、二进制帧格式——跨层通用

### 3.1 设计原则

```
1. 二进制，不是 JSON——感受数据高频小包（每 1ms 一帧），JSON 字符串解析不值得
2. 自描述——帧头带类型和长度，不需要外部 schema
3. 固定头 8 字节——解析器一眼看完决定路由
4. 多流标签——单 WSS 连接承载多种帧类型（模拟 QUIC 的多路复用）
```

### 3.2 帧结构

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version| Type  |     Stream ID (2 bytes)     |  Payload Len   |
| (4b)  | (4b)  |                             |   (3 bytes)    |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Timestamp ns                          |
|                        (8 bytes)                             |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                               |
|                    Payload (0..16MB)                          |
|                                                               |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

**字段说明**：

| 字段 | 大小 | 说明 |
|---|---|---|
| Version | 4 bit | 协议版本，当前 0x1 |
| Type | 4 bit | 帧类型（见下） |
| Stream ID | 2 bytes | 逻辑流标识，同一 WSS 连接多路复用 |
| Payload Len | 3 bytes | 载荷长度（最大 16MB） |
| Timestamp ns | 8 bytes | 设备端采集时刻（纳秒） |

**帧类型**：

```
0x0  DATA_FSIR       FSIR 前端信号帧（iCE40→边缘）
0x1  DATA_PSIR       PSIR 个性化信号帧（边缘→服务器）
0x2  DATA_DSIR       DSIR 设备路由帧
0x3  DATA_ESIR       ESIR 执行帧（服务器→边缘/客户端）
0x4  SIGNAL_SAFETY   安全信号（D3 grounding / 熔断）      最高优先级
0x5  SIGNAL_HEARTBEAT 心跳                                    低优先级
0x6  META_SESSION    会话元数据（开始/结束/标签）
0x7  META_CONFIG     配置同步
0x8  REPORT_INTROSPECTION  自省报告
0x9  ACK             ACK/NACK
0xA  reserved        预留
..F  reserved
```

### 3.3 Stream ID 分配规则

```
Stream 0x0001  高优先级——安全信号、熔断通知
Stream 0x0002  感受注入流（ESIR 下行）
Stream 0x0010  GSR 皮电信号（上行）
Stream 0x0011  HRV 心率信号（上行）
Stream 0x0020  四诊感知信号（上行）
Stream 0x0100  自省报告（双向，低优先级）
Stream 0x0101  配置同步（双向，低优先级）
Stream 0x0FFF  心跳
```

---

## 四、安全——从 v0.x 第一天就上

### 4.1 传输安全

```
v0.x:  TLS 1.3 (rustls) + WSS
v1.0:  QUIC 内置 TLS 1.3（零额外配置）
```

**决策**：v0.x 就直接上 TLS——不自签，不 HTTP 明文。Let's Encrypt 自动续。

### 4.2 认证

```
边缘设备:  JWT Bearer token，设备注册时签发，有效期 30d
          Token 内嵌 device_id + user_id + scope("edge")

客户端:    JWT Bearer token，用户登录时签发，有效期 24h
          Refresh token 有效期 30d（存数据库）

服务器间:  mTLS（双向 TLS），用服务证书
```

### 4.3 数据最小化

```
原则：原始神经信号数据不离开边缘设备
    边缘做 FSIR→PSIR 转换（sigmoidal 归一化 + 个性化阻尼）
    服务器只收 PSIR 强度的标量数组——不收原始波形

对应代码路径:
    iCE40 raw frame → feelingsd FSIR parser → PSIR → WSS → server
```

---

## 五、离线与优雅降级

复制 `network-protocol.md` 的降级策略，补充 v0.x 具体行为：

```
完全在线    全双工 WSS，所有流在跑

弱网络      WSS 重连 + 指数退避
            上行：PSIR 数据暂存边缘本地 ring buffer（最多 5 秒）
            下行：ESIR 缺失 → 本地 SessionManager 用上次缓存的锚点

断网        自动切本地模式：
            - SessionManager 继续跑本地 PBM
            - 感受输出用缓存的 PersonalityAnchor
            - 数据写入本地 PBM JSON（已有的 PbmStore）
            - 恢复网络 → WSS 重连 → 批量推积压的 session snapshots

设备离线    FPGA 看门狗硬熔断（GSR→GND，5ms 超时）
            比任何软件响应都快
```

**v0.x 离线队列实现**：`PbmStore`（已实现）天然支持离线存储。重连后用 `list_sessions()` 扫未同步的 session，逐个推。

---

## 六、Rust Crate 选型清单

### 6.1 v0.x 立即可用

| 功能 | Crate | 版本 | 理由 |
|---|---|---|---|
| 异步运行时 | tokio | 1.x | 事实标准 |
| HTTP/WS 框架 | axum | 0.8 | 轻量，tower 中间件 |
| WebSocket | tokio-tungstenite | 0.24 | 纯 Rust，axum 直接集成 |
| TLS | rustls | 0.23 | 纯 Rust，无 OpenSSL |
| 串口 | tokio-serial | 5.x | 跨平台串口 |
| JWT | jsonwebtoken | 9.x | 标准 JWT 库 |
| 序列化 | serde + serde_json | 已有 | 已引入 |
| 二进制帧 | bytes | 1.x | 零拷贝 buffer |

### 6.2 v1.0 QUIC 切换

| 功能 | Crate | 理由 |
|---|---|---|
| QUIC | quinn | 纯 Rust，最活跃，tokio 集成 |
| gRPC | tonic | gRPC over QUIC（tonic 0.12+ 支持） |

### 6.3 不引入的

| Crate | 理由 |
|---|---|
| protobuf/prost | v0.x 用自定义二进制帧，更轻。v1.0 QUIC+gRPC 时再引入 |
| OpenSSL | rustls 足够，不引入 C 依赖和编译问题 |
| gRPC-web / envoy | v0.x 不需要，WSS 直连浏览器 |

---

## 七、实施路线

```
v0.4  (当前)    PBM 本地持久化完成 (PbmStore)，SessionManager 基础就绪

v0.5            串口读取 + FSIR 帧解析 (tokio-serial)
                二进制帧编解码 (Frame codec)
               　　注释——1 处设计点仍待确认，见 §八

v0.6            feelingsd WebSocket client → 服务器
                feelings-server WSS acceptor + 帧路由
                本地离线队列 + 重连同步

v0.7            客户端 WSS 实时感受地图
                REST API（自省报告 + 会话历史）
                JWT 认证

v1.0            QUIC 全栈切换
                quinn 替换 tokio-tungstenite
                gRPC 替换自定义帧（或保留二进制帧 + QUIC 原生流）
```

---

## 八、设计问题（已拍板）

### Q1: v1.0 时自定义二进制帧 vs gRPC/protobuf？

```
A: 保留自定义帧，用 QUIC 原生流    — 对 Feelings 最自然，帧格式已为流优化
B: 切 protobuf + gRPC             — 工具链更标准，但 v0.x 帧格式要重写

决定：A。自定义帧 + QUIC 原生流。v0.x 的二进制帧格式已在 Core ADR 014 定稿。
```

### Q2: 边缘设备用 axum-server 还是直接 tokio-tungstenite 做 client？

```
A: tokio-tungstenite 直接做 client    — 边缘不需要 HTTP server，只需要 WS client
B: axum 同时做 client 和 server       — 边缘也可以有本地 HTTP API（调试页面）

决定：v0.5 走 A，v0.7 有本地 dashboard 需求时切 B。
```

### Q3: 数据库——存 Session/PBM/用户数据？

```
v0.x: SQLite 单文件（边缘 + 服务器统一）
v1.0: PostgreSQL（多用户/多租户）

具体 schema + 迁移策略留给 ADR 015。
```

### Q4: Session 同步触发机制？

```
A: push 枚举返回
B: poll 轮询
C: epoll 风格事件源（LT/ET 双模）

决定：C。Core ADR 014 定义了 SyncEventSource（AtomicU64 位掩码 + signal/ack），
feelingsd 在 LT 循环里 pending_events()。解耦 SessionManager 和网络层。详见 Core ADR 014 §四。
```

---

*感受是连续的流。v0.x 的 WebSocket 是那条河的临时木桥——够用、好修、不挡水流。QUIC 的大桥在图纸上，但桥墩的位置已经定好了。*
