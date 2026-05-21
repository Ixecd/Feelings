# Feelings-OS —— 极薄运行时，Unix 哲学 x 硬实时双调度

> 作者：qc
> 日期：2026-05-21
> 性质：Feelings 基础设施设计，不可降级
> 核心：六个小组件、一切皆文件、管道组合——但不是 Linux。是 animi v2.0 从 01 裸奔的底座。

---

## 零、为什么不是 Linux

通用 OS 擅长公平。Feelings 需要偏袒。

```
Linux 给你什么                   Feelings 需要什么
───────────────                 ──────────────
CFS 完全公平调度——每个进程轮流     双调度域——安全域硬实时永远优先
虚拟内存 + 缺页中断               物理连续内存池——零缺页，零交换
驱动在用户态等中断                FPGA 寄存器总线直写——一个时钟周期
网络栈 TCP/IP 七层                感受不走网络——总线直连设备
LRU 页面驱逐                     安全规则永不驱逐——LRU 不知道什么是保底包
systemd / 用户态 / 内核态         极小单一地址空间——无内核态用户态切换
```

不是 Linux 不够好。是 Linux 没被设计来管神经信号。

---

## 一、Unix 哲学 x 硬实时

Feelings-OS 的每个组件只做一件事。通过标准接口通信。一切皆文件。

```
组件                  只做一件事
────                  ──────────
mempoold              管理内存池的预分配和回收
schedulerd            双调度域——安域硬实时 > 感受域软实时 > 后台
busd                  主设备 → 从设备的总线驱动（时钟分发、信号路由）
cached                 四层缓存的物理管理（L0 BRAM → L1 线程 → L2 共享）
timerd                 全局 PLL 锁相时钟——所有设备共享同一个主时钟
logd                  审计日志写入——只追加，不修改，哈希链锚定

接口                  一切皆文件
────                  ──────────
/dev/ear              主设备（迷走神经耳支刺激 + 心率采集 + PLL 主时钟）
                      read  → 心率 / HRV / 当前 PLL 锁相偏移
                      write → 迷走神经刺激参数（电流/频率/脉宽）
/dev/wrist            腕部设备（皮肤电导采集 + 温度控制）
                      read  → 皮电 / 温度
                      write → 温度目标 + 振动参数
/dev/neck             后颈设备（本体感受采集 + 低频振动）
                      read  → 本体信号
                      write → 振动幅度/频率/节律模式
/dev/temple           颞部设备（EEG 采集 + 认知状态信号）
                      read  → EEG 频段功率（α/β/δ/θ/γ）
                      write → 认知刺激参数
/dev/companion        飞行陪伴体（摄像头 + 麦克风）
                      read  → 视觉/语音特征向量
                      write → 飞行姿态指令

/dev/safety           安全调度域状态
                      read  → 当前安域标志（0=正常, 1=预警, 2=SafetyHold, 3=紧急）
                      write → 只有 schedulerd 拥有写权限

/dev/mempool          内存池状态
                      read  → 各 block 层级的已用/空闲/碎片率
                      write → mempoold 拥有写权限

/dev/cache            缓存状态
                      read  → L0/L1/L2 命中率、驱逐率、当前占用
                      write → cached 拥有写权限
```

---

## 二、管道组合——Unix 精神的实时版本

通用 Unix 管道：`cat data.txt | grep "error" | sort | uniq -c`。文本流，秒级延迟。Feelings-OS 管道：设备文件流，帧级延迟。

```
Session 启动时的管线
    cat /dev/ear        → read 心率基线
    | animi personalize  → PBM 偏移 → PSIR
    | animi device_map   → 设备分配 → DSIR
    | animi codegen      → 帧级指令 → ESIR
    > /dev/ear           → write 迷走神经刺激参数
    > /dev/neck          → write 本体感受振动参数
    > /dev/wrist         → write 温度目标

不是文本流。是信号流。
每个组件是一个独立进程——Unix 风格。
管道连接的不是 stdout→stdin，是共享内存的固定帧缓冲区（mmap 零拷贝）。
```

帧缓冲区取代 Unix 管道的字节流——同一个机制，不同的介质。`/dev/ear` 的 read 和 write 两端走同一个内存池内的帧缓冲页。一帧 = 一页。写完直接切换指针——不经过内核缓冲区。

---

## 三、调度器——这层要偏离 Unix

Unix 说一切平等。Feelings 说安域永远是最高优先级。这是 Feelings-OS 在 Unix 哲学上唯一公开反叛的地方。

```
优先级      域               延迟要求      被谁抢占
──────      ──               ────────      ──────
P0          安全调度域         < 100μs      永远不被抢占——只在中断时切到安全插桩帧
P1          感受调度域         1ms 帧级      被 P0 抢占——安全事件发生时立即切
P2          设备 I/O           5ms           被 P0/P1 抢占
P3          后台预交织         不限           被 P0/P1/P2 抢占——只有 Idle 状态时跑

调度规则
    任何 P0 事件（心率超标 / 皮电骤升 / 设备断开）→ 立刻抢占当前运行的任何任务
    P0 帧 = 安全插桩帧 → 在 BRAM 端口 B 写入标志 → 下一拍端口 A 的 ESIR 被替换
    抢占延迟 < 100μs——不需要进程上下文切换，只在 BRAM 端口写一行寄存器

    P1 帧（1ms 帧级交织）在运行时——P2/P3 无法抢占
    只有在 P1 帧完成（释放当前时隙）后，P2/P3 才能获取 CPU
```

**Unix 的 CFS 给每个进程一样的时间片。Feelings-OS 的调度器给每个域不等的时间权。** 安域不是多一点——安域是全部。它要的时候，其他域立刻停止。

---

## 四、内存池——零动态分配的地基

全量物理连续。启动时分配完成。运行期零 malloc，零 free，零 GC。

```
block 层级      大小        数量        用途
──────────      ────        ────        ────
Page            4KB         N×1000     单帧 ESIR 参数 / 设备文件读写缓冲
Chunk           64KB        N×100      单 Session PSIR 上下文 / PBM 热行
Slab            1MB         N×10        PBM 全量矩阵 / FSIR 缓存
Zone            16MB        N×1        沙箱隔离区——未验证原子的独立内存区

分配规则
    Page  = 帧级，用完覆盖——不回收
    Chunk = Session 级，session 结束释放
    Slab  = 常驻——PBM 和 FSIR 缓存跨 session 保留
    Zone  = 固定分区——沙箱和核心逻辑物理隔离

零碎片保证
    每个层级的 block 大小相同 → 任何 block 都可以服务同层级的任何请求
    释放的 block 回到空闲链表 → 下次分配同层级立即可用
    永远不拆分、不合并不合并 block → 零外部碎片
```

---

## 五、总线驱动——主设备广播模型

主设备（耳后-FPGA）发出统一主时钟。从设备通过 PLL 锁定。

```
主设备指令周期

    每一帧（1ms）
        1. timerd 发送主时钟脉冲（PLL 参考信号）→ 所有从设备 PLL 锁定
        2. busd 轮询 /dev/wrist → 读皮电、温度
        3. busd 轮询 /dev/neck  → 读本体信号
        4. busd 轮询 /dev/temple → 读 EEG 频段功率
        5. 信号汇入 animi codegen → 计算本帧 ESIR
        6. busd 写入 /dev/ear   → 迷走神经刺激
        7. busd 写入 /dev/neck  → 本体感受振动
        8. busd 写入 /dev/wrist → 温度目标

    整个循环在一个 PLL 时钟周期内完成
    总线 = 柔性排线或极短距磁耦合——不经过任何 OS 协议栈
```

---

## 六、缓存集成

内存池是物理的。四层缓存是逻辑的。Feelings-OS 的 cached 进程负责把逻辑层映射到物理层。

```
cached 做的事

    L0 ─→ FPGA BRAM 双端口区
          cached 在启动时配置 BRAM 分区表
          端口 A = 感受域只读，端口 B = 安域只写
          运行时 cached 不干预——BRAM 自己按端口权限跑

    L1 ─→ 每线程独占的 Page/Chunk block
          cached 在 Session 启动时从 mempoold 划出 L1 区域
          L1 块绑定到 CPU 核心（affinity）——线程和 cache 物理最近

    L2 ─→ 节点级 Slab 区域
          cached 管理跨线程共享的 PBM 全量和 FSIR 缓存
          读写需要轻量锁（L2 锁只锁单个 entry——不是整个 L2）
```

---

## 七、和 Feelings 全栈的关系

```
Feelings 二十二层全栈          Feelings-OS 的对应层
────────────────────          ──────────────────
层 0-4  电子→晶体管→离散→机器码   FPGA 物理。Feelings-OS 不碰。
层 5    固件与实时系统           FPG 驱动层。busd 直连硬件。
层 6    设备硬件                /dev/ear /dev/wrist /dev/neck /dev/temple
层 7    信号处理                animi 前端——信号滤波、PLL 锁相
层 8    交织管线                animi 八 Pass——在 Feelings-OS 上作为独立进程运行
层 9    类型系统                animi 的 Pass 1——受 mempoold 的内存保护
层 10   数据架构                cached + mempoold——L1/L2 缓存物理管理

Feelings-OS 跨越层 5-10。
它向上给 animi 提供标准文件接口（/dev/*）。
向下给 FPGA 提供总线直连。
左右给安全域提供不可被抢占的中断响应。
```

---

## 八、最小启动序列

```
1. FPGA bitstream 烧录
2. mempoold 分配全量物理内存池
3. cached 配置 BRAM 分区表 + L1/L2 映射
4. busd 枚举设备 → 注册 /dev/ear /dev/wrist /dev/neck /dev/temple
5. timerd 启动 PLL 主时钟 → 所有设备锁定
6. schedulerd 启动调度循环 → Idle
7. animi 进程就绪，等待 Session 请求

总启动时间 < 2s——从加电到可服务。
没有 init 系统。没有登录。没有 shell。
只有六个进程 + 标准文件接口 + 调度器。
```

---

## 九、Feelings-OS 不是 OS

它是一个极薄运行时。刚好够不跟硬件打架。刚好少到不拖慢任何实时路径。

```
不管的事
    不管文件系统（有 MinIO + PostgreSQL，不在设备本地）
    不管用户登录/权限（设备认证在 FPGA 层——TEE + 生物特征）
    不管网络协议栈（感受不走网络——只走总线。后台预交织走 QUIC 是单独进程）
    不管虚拟内存（内存池 = 物理连续 + 固定映射——缺页中断 = 不存在）
    不管 shell、SSH、systemd、init、守护进程管理

管的事
    六个小组件各自做一件事
    标准文件接口——/dev/* ——read/write 操作
    严格优先级双调度域——P0 安域永远抢占
    总线设备驱动——主时钟 + 从设备轮询
    内存池零碎片预分配
    四层缓存物理映射
```

---

*Unix 说一切平等。Feelings-OS 说安域永远是最高优先级。这违背费 Unix。不违反感哲学。是 Feelings 自己的哲学。*
