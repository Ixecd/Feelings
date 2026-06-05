# 缓存架构——从寄存器到远程节点的多级存算体系

> 作者：qc
> 日期：2026-05-21
> 性质：Feelings 基础设施设计，不可降级
> 核心：内存池是地基，KVCache 是调度单元，四层缓存从 ns 到 ms 覆盖全链路

---

## 零、先定前提

Feelings 运行在计算机上。有进程。有线程。有协程。但通用 OS 的缓存架构不是为感受信号设计的——LRU 驱逐策略不知道什么是「当前 Session 的安全校验帧」，页面换出可能会把保底包从内存里踢走。

需要自己的缓存体系。从 ns 到 ms，每一层都精确知道自己在缓存什么。

---

## 一、硬件缓存基础——CPU 和 FPGA 的透明层

硬件缓存是 Feelings 逻辑缓存的物理载体。它们自己透明运行——CPU 的 L1/L2/L3 和 FPGA 的 BRAM 对上层代码来说不可见。但如果 Feelings 的数据结构不对齐硬件缓存的物理特性，延迟会翻倍，且你查不出原因。

### Cache line 对齐

x86 的 cache line 是 64 字节。每次缓存未命中时，CPU 从 DRAM 加载整个 64 字节块。如果 KVCache 的一个条目跨了两条 cache line——一次读取触发两次缓存填充——延迟翻倍。

```
对齐规则
    KVCache 条目的 payload 起始地址对齐到 64 字节边界
    priority 字段和 value 的首字节放在同一条 cache line 里
    → 一次读取拿到 priority + 判定驱逐 + value 全部
    → 不在同一条 cache line → 读两次 DRAM → 延迟 2×

结构体布局
    #[repr(C, align(64))]
    struct KvCacheEntry {
        key_hash: u64,       // 8 字节
        priority: u8,        // 1 字节——紧挨 key，同一 cache line
        ttl_ms: u32,         // 4 字节
        flags: u8,           // 1 字节
        value_ptr: *const u8, // 8 字节
        _pad: [u8; 42],      // 填充至 64 字节
    }
    // 整个结构体正好 64 字节 = 一条 cache line
```

### False sharing 防护

线程 A 和线程 B 各自操作同一个 KVCache 数组里的相邻条目。线程 A 的条目和线程 B 的条目落在同一条 cache line 上。A 写 priority → CPU 标记整个 cache line 为 dirty → B 的 L1 copy 失效 → B 重新从 L2 加载。即使 A 和 B 读写的不是同一个条目。

```
防护策略
    每条 KVCache 条目本来就是 64 字节对齐（≡ 独占一条 cache line）
    → 相邻条目不共享 cache line
    → 线程 A 写条目 [0] 不会让线程 B 的条目 [1] 的任何缓存拷⻉失效
    → 零 false sharing
    这是 64 字节对齐的附带效果——不用额外 padding
```

### FPGA BRAM 分区——双端口读写

L0 层存在 FPGA 的 BRAM（Block RAM）里。BRAM 天然支持双端口——端口 A 读，端口 B 写，同一时钟周期内完成。

```
BRAM 分区策略

    端口 A（只读）    主调度域的 ESIR 帧参数读取
                     感受参数、设备映射结果、当前帧时间戳
    端口 B（只写）    安全调度域的插桩标志写入
                     心率超限标志、皮电异常标志、紧急停止标志

    两端口的地址空间不重叠
    → 主调度域和安域在同一时钟周期内各自访问独立 BRAM 块
    → 零端口冲突，零等待周期
```

### 显式预取

CPU 有硬件 prefetcher——检测到连续访存模式后自动预取后续 cache line。但 Feelings 的数据访问模式不总是连续的——预测器输出的下一帧 key 可能跳到一个不连续的位置。

```
显式 prefetch 的位置

    Pass 6 (Personalize)
        → 本帧使用了 PBM 行 [calm, row_42]
        → 预测器给出下一帧 ŝₜ₊₁ 需要 PBM 行 [calm, row_45]
        → 显式 _mm_prefetch(&pbm[calm][row_45], _MM_HINT_T0)
        → 不等 Personalize 在 L2 里查不到才 miss
        → 提前把 row_45 拉进 L1

    Pass 8 (CodeGen)
        → ESIR 帧顺序写入 L0 BRAM——天然连续，硬件 prefetcher 自己搞定
        → 不需要显式 prefetch
```

硬件缓存不是透明就不管。对齐策略直接影响延迟——64 字节对齐是零成本的加速。false sharing 的防护对齐附赠。BRAM 双端口分区是结构决定的——主域和安域各自拥有独立端口。显式 prefetch 只在一处需要——预测器跳转。

---

## 二、地基——内存池

内存池不是缓存。内存池是预分配的固定内存区域，零动态分配，零 GC。

```
通用 OS 的分配方式
    malloc / free → 碎片 → GC pause → 延迟不可预测

Feelings 内存池
    启动时预分配 N 个固定大小的 block
    每层缓存从内存池中划出自己的区域
    零运行期分配。零碎片。零 GC。
    block 大小分级：
        4KB    — 单帧 ESIR 参数
        64KB   — 单 session PSIR 上下文
        1MB    — PBM 全量矩阵
        16MB   — 沙箱隔离区
```

**每一层缓存都是内存池的一个切片。** 内存池是物理的，缓存是逻辑的。物理上只有一块连续内存——逻辑上被 L0/L1/L2/L3 四层缓存视图覆盖。

---

## 三、KVCache——最小调度单元

KVCache 是 Feelings 的原子缓存单元。不是通用的 key-value store——是针对感受数据定制的。

```
KVCache 条目

    key      复合键
             类型前缀    "feeling_atom" / "safety_rule" / "pbm_row" / "esir_frame"
             ID          atom_id / session_id / frame_index
             版本号      来源版本（Pattern Registry 版本 / PBM 版本）
    value    固定大小 payload——不超一个 block
    ttl      生存时间——0 = 永不过期（安全规则），>0 = 过期后刷新
    priority 1-5——5 = 安全规则（永不驱逐），1 = 历史 session 数据
    lock     读写锁——写锁占有时读者等待，保证原子更新
```

**KVCache 不做通用驱逐。** 驱逐策略按 priority 分级——priority 5 和 4 永不驱逐，priority 3 按 TTL 过期，priority 1-2 按 LRU。通用 OS 的 cache 不知道你的 value 是安全校验帧还是历史 session 数据。它们看起来都一样——但安全校验帧被踢出内存的代价是人的神经系统。

---

## 四、四层缓存

### L0 — 寄存器级 (ns)

存在 FPGA 内部。一个总线周期。不经过内存控制器。

```
容量        KB 级别
延迟        1-10ns（FPGA 总线周期）
存储内容    - 当前帧 ESIR 参数
            - 上一帧生理反馈寄存器值
            - 当前 PLL 锁相信号
           - 安全插桩触发标志
驱逐策略    不驱逐。帧结束后自动覆写。
对应实体    FPGA 内部寄存器文件 + 分布式 RAM
```

L0 不存在「缓存未命中」的概念。因为它就是最终执行的地板。每一帧读写 L0 是硬实时的——没有 cache miss，只有这一拍的数据必须在这里。

### L1 — 线程级 KVCache (ns-μs)

每个交织线程独占。线程内的感受数据不跨线程共享——没有锁竞争。

```
容量        MB 级别（每线程 4-16MB）
延迟        10-100ns（L1 cache hit - 通常 4-6 个 CPU 周期）
存储内容    - 当前 session 的 PSIR 全量上下文
            - PBM 当前活跃行（正在被 Personalize 使用的偏移向量）
            - Pattern Registry 热条目（高频查询的感受原子定义）
            - 安全规则索引（强度上限、点缀配比上限的快速查找表）
            - 声明式注解展开后的插桩模板
驱逐策略    priority 5（安全规则索引）— 永不驱逐
            priority 4（当前 PSIR）— 永不驱逐
            priority 3（PBM 活跃行）— TTL + 近期最少使用
            priority 2（Registry 热条目）— LRU
对应实体    CPU L1/L2 cache 内的热数据。线程绑定 CPU 核心。
```

**KVCache 的 L1 层是单线程独占的。** 一个交织线程处理一个 session。它的 KVCache 不和任何其他线程共享。没有锁。没有竞争。感受数据天然是会话隔离的——同一个 session 跨线程共享只会增加延迟，不会增加吞吐。

### L2 — 节点级共享缓存 (μs)

单个 Feelings-Server 节点内所有线程共享。跨线程访问需要轻量锁。

```
容量        GB 级别（每节点数 GB）
延迟        100ns-1μs（L3 cache hit 或本地 DRAM）
存储内容    - PBM 全量矩阵（所有用户的完整基线数据）
            - Pattern Registry 全量（所有感受原子的完整定义和验证数据）
            - FSIR 缓存（已预编译的感受包 FSIR JSON）
            - 历史 session 元数据（不包含原始生理数据——那些在设备上）
            - 沙箱隔离区（未验证原子的独立内存区域）
驱逐策略    priority 5（PBM 安全相关行）— 永不驱逐
            priority 4（当前活跃用户的 PBM）— 永不驱逐
            priority 3（FSIR 缓存）— TTL + LRU
            priority 2（历史元数据）— LRU
            priority 1（日志/审计/非实时数据）— 可交换至磁盘
对应实体    服务器 DRAM 中的内存池区域
```

L2 是「这个服务器知道的东西」。它不包含任何原始生理数据——那些在设备上。但它有每个人的基线、所有验证过的感受原子、所有预编译的 FSIR。当一个 session 启动时，L2 在微秒级把 PBM 全量和 FSIR 上下文推到 L1。

### L3 — 共享存储池 (μs-ms)

跨节点共享。多个 Feelings-Server 节点访问同一个逻辑池。

```
容量        数十 GB 至 TB 级
延迟        1μs-10ms（取决于网络跳数——通常在同一数据中心内）
存储内容    - 全量 Pattern Registry（所有版本）
            - 全量 SPL 账本（哈希链索引）
            - Session 审计日志
            - 设备固件版本镜像
            - PBM 冷备份（非活跃用户的基线存档）
            - 沙箱原子库（未验证原子的隔离存储）
驱逐策略    priority 3+ 不驱逐
            priority 1-2 可归档至冷存储
对应实体    分布式内存池——PostgreSQL + Redis + MinIO 的组合视图
```

L3 是「整个 Feelings 系统知道的东西」。它是共享的，但共享的不包含任何设备上的私密数据。L3 存储的是公共的、可验证的、审计的信息——Pattern Registry、SPL 账本、固件镜像。

### Remote — 远程缓存 (ms)

**不确定能不能实现。** 但值得留一个位置。

如果多个数据中心需要共享 Pattern Registry 更新、设备固件分发、SPL 账本节点同步——就需要 remote 层。但 remote 层延迟是毫秒级的。不适合任何实时交织管线。只适合异步的数据同步——Registry 更新分发、固件 OTA、审计日志汇总。

```
Remote 层如果做
    延迟        10-100ms（跨地域网络）
    存储内容    - Pattern Registry 的跨数据中心同步副本
                - SPL 账本的异地镜像
                - 固件 OTA 分发
                - 审计日志的远程汇总
    不做的事     不参与任何实时 session 的缓存查询
                 不参与安全校验——安全校验在 L0/L1 完成
```

Remote 层是一条「如果」链路。如果只有一个数据中心——不需要。如果多个数据中心需要共识——需要。但即使需要，它不和实时管线对话。**实时管线的缓存永远在 L0-L2 内闭环。**

---

## 五、缓存抽象层

四层缓存在物理上是不同的硬件——FPGA 寄存器、CPU cache、DRAM、分布式存储。逻辑上，对 animi 的每个 Pass 来说只有一件事——`get(key) → value`。

```
缓存抽象接口

    trait CacheLayer {
        fn get(&self, key: &CacheKey) -> Option<CacheValue>;
        fn put(&self, key: CacheKey, value: CacheValue, ttl: Duration);
        fn invalidate(&self, key: &CacheKey);
    }

每一层实现同一个 trait。
    L0  = FpgaRegisterCache
    L1  = ThreadLocalKvCache
    L2  = NodeSharedCache
    L3  = DistributedPoolCache

对 animi 的 Pass 来说：
    Pass 6 (Personalize) → 查询 PBM 行 → cache.get("pbm_row:user_001:calm")
    → 抽象层自动从 L1（命中）或 L2（未命中→回填 L1）返回
    → Pass 不需要知道数据在 L1 还是 L2
```

**缓存命中下沉。** 同一个 key 在 L1 命中了就不用查 L2。L1 是 L2 的子集——不是全量复制，是热数据窗口。L2 未命中则查 L3——查到的结果回填 L2 和 L1。L3 是从磁盘或远程加载的入口。

---

## 六、和其他架构组件的关系

```
内存池        物理内存的预分配——缓存层的物理基础
KVCache       逻辑缓存单元——内存池的每个 block 是一个 KVCache 条目
四层缓存      逻辑分层——从 ns 到 ms 覆盖全链路
缓存抽象层    统一接口——animi 的 Pass 不感知缓存层级

animi Pass 的缓存使用

    Pass 0-1 (LexParse/TypeCheck)
        → 查询 Pattern Registry → L1（热条目）→ L2（全量）→ L3（版本回退）

    Pass 2-4 (Safety)
        → 查询安全规则索引 → L1（永不驱逐）
        → 安全规则在 animi 启动时从 L2 加载到 L1，session 期间不换出

    Pass 5 (FSIRGen)
        → FSIR 缓存查询 → L2
        → 离线预交织时 FSIR 写回 L2，下次 session 启动时直接命中

    Pass 6 (Personalize)
        → 查询 PBM 活跃行 → L1（当前用户）→ L2（全量用户 PBM）
        → PBM 冷启动系数 → L2（固定查找表）

    Pass 7 (DeviceMap)
        → 设备能力描述 → L1（当前连接设备）
        → 当前设备组合在 session 开始后不变，全在 L1

    Pass 8 (CodeGen)
        → L0 直写——ESIR 每帧写 FPGA 寄存器
        → 不经过 L1/L2/L3。1ms 一帧，直接写入 L0
```

---

## 七、什么是「缓存命中的安全保证」

通用缓存系统——LRU 驱逐。不管内容是什么。八百年不用的变量和下一秒就要执行的安全校验帧——排队等驱逐。谁久没被碰就踢谁。Feelings 不能这么干。

```
安全规则的缓存状态

    加载时机     animi 进程启动时
    存放层级     L1——永不驱逐。L2——永驻。L3——全量冗余
    失效条件     Pattern Registry 版本更新——手动刷新，不自动过期
    读取方式     Pass 2-4 在每次交织时查询——O(1) 哈希查找
    降级策略     L1 未命中 → L2 未命中 → **拒绝交织，不是降级继续**
                  安全规则不完整 = 不允许生成任何感受信号

生理安全插桩的缓存状态

    加载时机     Pass 4 生成后，注入 L0
    存放层级     L0——硬实时读取，和当前帧绑定
    失效条件     帧结束自动覆写
    降级策略     L0 未命中 → 整个 session 进入 SafetyHold 状态
                 等待 L1 重新加载插桩模板 → 重新写入 L0
```

---

*内存池是地。KVCache 是砖。四层是楼。从 ns 到 ms——每一层都知道自己在守着什么。*
