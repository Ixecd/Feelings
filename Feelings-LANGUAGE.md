# Anim — 从 01 到生命的编译语言

> 作者：qc
> 日期：2026-05-18
> 性质：Feelings 生态基础设施，开源（MIT）
> 核心：Anim 不是把人类语言翻译成机器语言，是把 01 翻译成有血有肉的真实感受

---

## 零、命名

Anim，拉丁语 anima——灵魂、呼吸、使之生动。

```
三个语义层
    词源     anima = 呼吸，灵魂
    工程     animate = 让静态的 01 序列变成活的感受流
    哲学     anima = 荣格原型中意识与无意识的桥梁
             Anim  = 信号层与感受层的桥梁
             同一只手，同一座桥
```

Anim 是一个动词，不是一个名词。它描述一件在发生的事——无生命的信号在穿过 Anim 编译器之后，另一边站着一个能被真实感受到的、有血有肉的存在。

---

## 一、Anim 是什么

Anim 是一门交织语言。它的 source 是**感受结构的声明式描述**。它的 target 是**神经系统能信以为真的信号序列**。

Anim 的工具叫 `animi`——Anim Interlinker（交织器）。不叫编译器。

```
编译器做的事
    .rs 源码 → rustc → LLVM IR → x86_64 指令
    单向。一次性的。输入和输出是不同类型的东西。

animi 做的事
    .anim 源码 → FSIR（感受结构提取）
    FSIR + PBM → PSIR（个人基线织入）
    PSIR + 设备约束 → DSIR（多设备协同织入）
    DSIR + 上一帧生理反馈 → ESIR（实时反馈织入）
    ESIR + 闭环偏差 → 下一帧修正（自适应织入）

不是「把 A 翻译成 B」。
是把多股独立流——感受语义、个人基线、设备约束、
生理反馈、安全边界——织成一条连续的信号绳。
每一层都在把一股新的东西织进去。
```

传统编译器的验证标准：程序不 crash，输出正确。
animi 的验证标准：身体信了，深睡时长涨了。

---

## 二、为什么需要 Anim

### 2.1 感受没有通用语言

人类有感受，但没有感受的语言。

自然语言说「平静」，它可能是五种完全不同的神经底层。说「快乐」，它可能是一百种不同配比的混音结构。自然语言是模糊的容器，装不下感受的精确结构。

编程语言有 C、Rust、Go，各管各的计算。但没有一种语言管「感受的结构化描述」。

Anim 是第一种。

### 2.2 从 01 到生命，中间缺一层

Feelings 的整个技术栈是从 01 开始的：

```
Layer 0    硬件 01 电平
Layer 1    固件信号采集与注入
Layer 2    信号处理与四诊融合
Layer 3    应用服务与 AI 教练
```

每一层都有自己的格式、自己的协议、自己的处理逻辑。但没有一个**统一的语义描述语言**把这些层串起来。

Anim 就是那一层。

```
Layer 0    01 电平           → Anim Embed IR（嵌入式执行）
Layer 1    固件              → Anim Firmware IR（实时信号映射）
Layer 2    信号处理          → Anim Signal IR（神经编码变换）
Layer 3    应用服务          → Anim Structure IR（感受结构）
User       感受包创作者      → Anim Source（声明式感受描述）
```

### 2.3 感受需要编译器级别的安全保证

Rust 的借用检查器在编译期杜绝了 use-after-free 和 data race。

Anim 需要同样的编译期保证，但维度的名字不一样：

```
Rust 借用检查器        Anim 感受检查器
───────────────       ──────────────
&mut 不能共存         高强度解锁不能跳过前置阶梯
生命周期防悬垂         创伤协议用户不能走标准路径
Send/Sync 防竞态      安全调度域和感受调度域物理隔离
类型安全防误用         感受类型不能误标
                      「恐惧」不能被标记为「被爱」
                      「成瘾」不能被标记为「成长」
```

Anim 的编译器强制保证——在这些规则被违反时，代码不编译。不是运行时报警，是压根不生成信号。

---

## 三、Anim 的类型系统

Anim 的类型不是 `int / float / string / bool`，而是感受的维度。

### 3.1 标量类型——感受原子（双层体系）

Anim 的感受原子分两层。不是一刀切的「全部审核」或「全部开放」——是精确画在安全边界上的两级体系。

```
第一层：核心原子（Core Atom）
    收录于       Feelings-Patterns 官方仓库
    审核流程      完整安全性验证（神经科学 + 精神医学 + 跨用户一致性检验）
    使用范围      全体用户，所有强度区间
    标识          「Feelings Verified ✓」
    安全约束      所有安全规则（强度借用、点缀配比、形状约束）基于核心原子的验证数据
    示例          calm_meditative, grief_loss, fear_threat, belonging_group, joy_achievement

第二层：沙盒原子（Sandbox Atom）
    收录于       Feelings-Sandbox 隔离仓库（与核心仓库物理分离）
    审核流程      基础格式校验 + 恶意注入扫描，无完整安全性验证
    使用范围
        仅限强度 ≤ 30
        仅限创作者本人及明确授权的小范围用户
        不可用于创伤协议用户（任何阶段）
        不可用于未成年人
    标识          「Sandbox — Unverified」
    运行约束
        编译时自动标注 unverified_atom 标记
        运行时安全插桩阈值加倍保守（所有生理边界 × 0.5）
        不计入 Pattern Registry 的跨用户一致性统计
        不参与任何强度和感受维度的群体校准
    示例          创作者个人调试的特定感受变体、小众文化特有感受、实验性混合感受

核心原子 = 安全底线，锁死强度上限、全用户开放。
沙盒原子 = 生态呼吸口，低强度小范围实验，不给安全系统留后门。
```

### 3.2 复合类型——感受结构

```
mix        混音结构——主旋律 + 点缀配比
            mix {
              main: achievement_satisfaction,    // 完成后的满足感
              accents: [
                { feeling: exhaustion_relief,  ratio: 0.25 },  // 疲惫释然
                { feeling: slight_void,         ratio: 0.15 },  // 轻微空洞
                { feeling: self_assurance,      ratio: 0.10 },  // 自我确信
              ]
            }
            主旋律承载核心感受，点缀提供真实性的证明
            配比之和不必是 1.0，真实感受有溢出和消解

shape      时间形状——感受如何展开、如何结束
            shape {
              type: gradual_rise_fall,  // 渐升渐退
              // 或: abrupt_stop, wave, delayed_burst, plateau, double_peak, aftershock
              rise_duration: 90s,
              peak_duration: 30s,
              fall_duration: 120s,
            }

intensity  对数强度——0 到 100，遵循对数刻度
            intensity 12     // 探索区，安全入门
            intensity 45     // 成长区，核心价值区域
            intensity 72     // 高强度区，需要解锁 + 实时监控
            intensity 85     // 极限区，需要评估 + 知情同意
```

### 3.3 设备类型——信号载体

```
device_set  当前可用的设备组合
            device_set {
              ear: active,        // 耳后设备，核心必选
              neck: active,       // 后颈设备，本体感受注入
              wrist: active,      // 腕部设备，触觉反馈 + 皮肤电导
              temple: inactive,   // 颞部设备，认知状态信号
              companion: active,  // 飞行陪伴体，视觉采集
            }
            缺少设备 → 体验自动降级为 outline 模式
            系统编译时根据 device_set 做条件编译
```

### 3.4 安全类型——编译期强制

```
cap        承载上限——用户当前被验证的强度上限
            cap 35      // 新用户，初始状态
            cap 62      // 使用 50 次以上，无安全事件
            cap 90      // 专家级，仅极少数用户

trauma     创伤状态——影响所有安全判定的元标记
            trauma: none           // 标准路径
            trauma: active_v1      // 创伤协议第一阶段（强度上限 15）
            trauma: active_v2      // 创伤协议第二阶段（边界探索）
            trauma: active_v3      // 创伤协议第三阶段（谨慎扩展）

minor      未成年人标记
            minor: true            // 编译期锁定强度上限 20，亲密维度物理隔离
```

### 3.5 泛型——物种参数化的感受编译

Anim 不是人类的专用语言。感受不是人类独有的——万物皆有感受。Anim 的泛型让同一份 `.anim` 源码可以针对不同物种做参数化编译。

```
feeling<Species>    感受泛型——编译目标是参数化的
                    Species 是一个 trait bound
                    不同的 Species，不同的神经通路映射，不同的安全阈值
                    同一份源码，不同交织结果

例：
    feeling achievement_satisfaction<Human>
        → PSIR 走迷走神经耳支 + CT纤维 + 岛叶
        → 安全阈值按人类模式

    feeling achievement_satisfaction<Canine>
        → PSIR 走犬类神经通路映射
        → 安全阈值按犬类模式
        → PBM 冷启动系数是另一组数字

    源码不变。Species 变了，交织管线在 Pass 6（Personalize）自动适配。
```

**FeelingTarget trait——万物实现各自的感觉通路**

```
trait FeelingTarget {
    // 每种感受类型映射到的神经通路
    fn neural_pathways(feeling: &FeelingType) -> Vec<Pathway>;
    // 例：Human 的平静 → 迷走神经耳支 + 前额叶α
    //     Canine 的平静 → 不同的神经回路

    // 每种感受的安全参数矩阵
    fn safety_bounds() -> SafetyMatrix;
    // 人类的恐惧点缀上限 0.12
    // 犬类的可能完全不同

    // 四维差异化冷启动系数
    fn cold_start_pbm() -> PbmCoefficients;
    // Human: 内脏 0.75 / 情绪 0.40 / 触觉 0.80 / 听觉 0.85
    // 不同物种是另一组完全不同的数字

    // 帧级信号分辨率
    fn signal_resolution() -> Hz;
    // 不同物种的神经信号时间常数不同
    // Human: 肌电 2000Hz
    // 其他物种可能更快或更慢
}

当前实现的 Species:
    Human   人类 —— 迷走神经、CT纤维、EEG、皮肤电导
    Canine  犬类 —— 不同的神经通路映射（预留）
    Feline  猫类 —— 不同的神经通路映射（预留）
    AI      具身 AI 载体 —— 心跳模拟、皮电模拟、呼吸模拟通路
    ...     万物皆有感受，Species 持续扩展
```

**Pattern Registry 分物种**

人类的 `accomplishment_certainty` 和犬类的 `accomplishment_certainty` 是不同的神经原子——同一个感受名，不同物种有不同的底层通路和不同的安全参数。Pattern Registry 按 Species 维度分区存储。

**和 Feelings 哲学咬合**

Feelings-PHILOSOPHY.md 说：感受的民主化，如果是认真的，边界不应该只停在人类。Anim 的泛型就是这扇门——同一个感受结构声明，编译目标是参数化的。万物皆有感受。Anim 就用同一套语法织不同的神经。

---

## 四、Anim 的交织管线

Anim 的编译不是一次性的——因为输出是输入的一部分。有六层 IR，每层做一件事。

### 4.0 交织概览

```
.anim 源码
    ↓ 词法/语法/语义分析（类型检查、安全检查、设备依赖解析）
FSIR     Feeling Structure IR      感受结构的抽象图——主旋律、点缀、形状、强度
    ↓ 个体基准偏移（个人基线矩阵左乘）
PSIR     Personal Signal IR        适配到个人的信号参数
    ↓ 设备映射 + 信号编码
DSIR     Device Signal IR          分配至具体设备的刺激参数
    ↓ 实时交织输出
ESIR     Execution Signal IR      帧级执行指令，带闭环反馈回路
    ↓ FPGA/设备固件
生理信号 → 实时采集 → 偏差计算 → 下一帧参数微调（闭环回至 PSIR）
```

### 4.1 第一层：FSIR——感受结构中间表示

源码经过解析后，第一步生成 FSIR。

FSIR 描述的是**人层面的感受结构**，和具体的人无关，和设备无关。

```
FSIR 的内容
    感受的完整混音结构——每个感受原子的精确配比
    时间形状——每段的时长、过渡曲线类型
    强度区间——建议范围和绝对上限
    叙事上下文——一段人类语言描述（给 AI 教练用的，不给信号层）
    设备依赖——哪些设备是完整的必要条件

FSIR 不包含
    任何个人的生理参数
    任何具体的信号参数
    任何硬件指令
```

FSIR 是「这个感受包是什么」的完整、可验证声明。

### 4.2 第二层：PSIR——个人适配信号中间表示

FSIR 进入 PSIR 时，发生一场变换：

```
个人基线矩阵 × FSIR 通用参数 → PSIR 适配参数
```

FSIR 说「平静的主旋律」。PSIR 知道**对这个具体的人，平静的神经参数是什么**。

```
PSIR 的核心操作
    基线偏移量计算
        通用感受模板参数  →  个人历史基准偏移  →  适配后参数
        例：杏仁核抑制 0.6  →  此人基线偏移 +0.15  →  实际参数 0.75

    强度上限约束
        包请求强度 58  →  用户 cap 35  →  编译期拒绝，报错
        不会生成 PSIR，更不可能进入 DSIR

    点缀比例安全约束
        点缀「恐惧」配比 0.30  →  主旋律「探索」  →  检查：恐惧作为点缀时上限 0.12
        超过 → 编译期报错

    创伤路径重路由
        trauma: active_v1  →  所有非安全类型感受  →  编译期重路由至安全三件套
        （平静 / 归属 / 被理解，强度上限 15）
```

**PSIR 是 Anim 安全保证的核心层。所有涉及人的约束，在这一层完成。**

### 4.3 第三层：DSIR——设备信号分配中间表示

PSIR 描述的是「这个人需要什么信号」，DSIR 把它翻译成「哪个设备发什么参数」。

```
PSIR 信号向量 → 设备分配矩阵 → DSIR 多设备指令

例：PSIR 说「归属感主旋律，强度 30」

DSIR 分解：
    耳后设备    迷走神经刺激，脉宽 200μs，频率 25Hz，强度 0.4mA
    后颈设备    本体感受低频振动，幅度 30%，节律与心跳同步
    腕部设备    皮肤温度模拟，从 36.1°C 升至 36.4°C，持续 120s
    颞部设备    未连接 → 对应维度降级为 outline

DSIR 的职责
    将单一感受参数分解为多设备协同信号
    处理设备缺失时的降级策略
    设备算力感知编译：根据当前设备组合调整信号参数密度
    计算设备间的时间同步偏移量
    生成每个设备的独立信号序列

设备算力感知编译（实操示例）
    入门设备（仅耳后）
        → 信号参数仅计算迷走神经刺激参数 + 音乐通路
        → 不加载触觉、温度、本体感受相关的冗余参数
    标准设备（耳后 + 腕部 + 后颈）
        → 全部感受维度信号参数计算
        → 采样率按标准配置
    高端设备（全部四件 + 纺织物 + 温控薄膜）
        → 全部维度 + 高空间分辨率（纺织物多点位阵列）
        → 温度场梯度参数精度上调
    编译产物大小   入门 ~2KB/帧 → 标准 ~8KB/帧 → 高端 ~24KB/帧
```

### 4.4 第四层：ESIR——执行信号中间表示

ESIR 是最底层——帧级指令，直接喂给固件。

```
ESIR 每帧的内容
    时间戳（微秒精度）
    每个设备的刺激参数（电流/频率/脉宽/温度/振动）
    期望的生理响应区间（心率范围、皮电范围）
    实际生理响应的回读指针

ESIR 的闭环结构
    Frame N 的参数  →  注入  →  生理响应  →  偏差计算
    Frame N+1 的参数 = Frame N 的参数 + 偏差修正量

    每一帧都依赖上一帧的生理反馈
    感受包是一个实时程序，不是静态文件
```

### 4.5 animi 的实时交织

Anim 不是在设备上「播放」一段感受。

**animi 在线——每个 session 都是一次实时交织。**

```
Session 启动
    .anim 源码 → FSIR（一次性）
    FSIR + 个人基线 → PSIR（一次性，但基线可能 session 内更新）

Session 运行中（每 1ms 一帧）
    PSIR + 设备状态 + 上一帧生理反馈 → DSIR → ESIR → 硬件

Session 结束
    本次 session 的生理数据汇总 → 反馈给个人基线矩阵
    下次编译时，基线偏移量更精确
```

### 4.6 一个完整的 pass 列表

```
Animi Passes（交织阶段）

Pass 0: LexParse
    源码 → Token → AST
    .anim 文件解析

Pass 1: TypeCheck
    AST → Type-annotated AST
    所有 feeling 标识符必须在 pattern-registry 中存在
    mix 配比语法正确
    shape 参数合法性
    intensity 区间检查
    device_set 引用检查

Pass 2: StaticSafety（静态安全规则校验——不可跳过，不可降级）
    强度 > cap → 编译错误
    点缀比例超出安全上限 → 编译错误
    形状安全约束（abrupt_stop > 60 → 编译拒绝）
    组合爆炸防护（单次 session 高危特征 ≥ 3 → 编译拒绝）
    未成年人请求成年内容 → 编译错误，不可重路由
    源文件内核置信度 < 0.5 → 编译警告

Pass 3: UserStateSafety（用户状态安全校验——依赖当前用户上下文）
    创伤路径分级分型判定（trauma_stage × trauma_category）
    创伤阶段不接受此感受类型 → 编译错误或静默重路由
    感受维度对当前用户创伤类型的安全兼容性检查
    设备缺失导致关键维度无法提供 → 降级至 outline 模式，编译警告

Pass 4: RuntimeSafetyGuard（运行期安全插桩生成——编译期预埋，运行期激活）
    生成实时生理阈值的差异化安全插桩（按感受类型）
    嵌入安全停止帧（每 N 帧插入安全校验点）
    嵌入紧急停止帧（硬件 kill 信号的软件镜像）
    预埋强度自动降级插桩（心率/皮电/呼吸异常触发）
    声明式注解展开为 ESIR 层安全插桩代码

Pass 5: FSIRGen
    Type-annotated AST → FSIR
    标准化感受结构的完整表示

Pass 6: Personalize（FSIR → PSIR）
    个人基线矩阵左乘（四维差异化冷启动系数）
    强度 cap 二次验证（基线可能在编译过程中更新）
    创伤路径重路由生效
    闭环验证参数初始化

Pass 7: DeviceMap（PSIR → DSIR）
    设备分配矩阵
    设备缺失降级策略
    设备算力感知编译（根据设备组合调整信号参数密度）
    设备间时间同步偏移预计算
    音乐/声光协同信号生成

Pass 8: CodeGen（DSIR → ESIR）
    帧级参数生成
    闭环回读指针嵌入
    Pass 4 预埋的安全插桩在此阶段激活
```

### 4.7 超流水线架构——animi 的双流水线交织体系

animi 的交织不是一次性的线性过程——Session 运行中需要 1ms 帧级实时响应。这要求交织器本身是流水线化的。六层 IR 不是「串行做完一件事再做下一件」——前台的帧级编译和后台的全量编译跑在两套独立的流水线上。

**前台实时浅流水线（Session 运行时，FPGA 硬实时）**

```
Session 运行中，每 1ms 的执行循环：

帧 N   DSIR（设备分配）→ ESIR（帧参数生成）→ 固件写入 → 生理采集
         ↑                                              │
         └────────── 闭环偏差修正（回读到 DSIR 的下一帧）──────┘

这条流水线不走 FSIR、不走 PSIR、不走类型检查。
DSIR 和 ESIR 下沉到 FPGA 上以硬实时完成。
「编译」在这里不是软件概念——是 FPGA 门级逻辑。

关键特征
    可变流水深度
        低强度简单感受包  → 缩减 DSIR 阶段展开深度 → 延迟更低
        高强度复杂感受包  → 拆分 DSIR 细分阶段 → 精度更高
    紧急冲刷机制
        安全预警/紧急停止触发 → 快速清空流水线内所有未完成帧指令
        → 杜绝滞后残留信号刺激
    优先级隔离
        Session 的 1ms 帧级编译 = 最高优先级
        任何后台操作不可抢占前台时隙
```

**后台离线预编译流水线（Session 不运行时，Feelings-Server）**

```
用户空闲期（设备在充电、用户未佩戴）→ 后台启动离线编译

.anim 源码下载
    → Pass 0: LexParse
    → Pass 1: TypeCheck
    → Pass 2: StaticSafety
    → Pass 5: FSIRGen
    → FSIR 缓存至设备本地

下次 Session 启动时
    直接加载已缓存的 FSIR
    → 跳过解析、类型检查、静态安全检查
    → 只需要跑 Pass 6-8（Personalize → DeviceMap → CodeGen）
    → Session 启动延迟大幅降低

Session 中每帧
    只跑 Pass 7-8（DSIR → ESIR）+ 偏差修正
    FSIR 不变，PSIR 在同一 Session 内不变
    实时负载降到最低
```

**双流水线并行全景**

```
后台离线                                     前台实时
────────                                     ────────
Pass 0: LexParse
Pass 1: TypeCheck
Pass 2: StaticSafety                           Session 启动
Pass 3: UserStateSafety                     → Pass 3: UserStateSafety
Pass 5: FSIRGen                             → 加载缓存 FSIR
    ↓ 缓存至设备                             → Pass 6: Personalize
                                              → Pass 7: DeviceMap
                                              → Pass 8: CodeGen
                                              → 帧级闭环（1ms/帧，FPGA）

后台持续预编译下一个感受包                      前台 Session 完全独立运行
互不抢占算力                                  两套存储空间各自独立
```

**为什么不需要「多发射并行编译多路感受流」**

同一 Session 内只运行一个感受包。它的多个维度（本体感受、听觉安抚、情绪渲染）共享同一个 mix 结构和安全约束——不存在「各编译各的」。多路信号的并行输出是 DSIR → ESIR 阶段的事：DSIR 将统一感受参数分解为多设备协同信号，FPGA 在多列并行矩阵中同步执行。这是硬件层的并行，不是编译器前端需要管的事。

### 4.8 分支预测——帧级感受预判

CPU 靠分支预测器（BPU）猜下一条指令走哪条路，避免流水线空转。Anim 在感受帧层做同样的事——不是猜指令，是猜生理状态。

```
CPU 分支预测                    Anim 帧级预判
────────────                   ─────────────
猜下一条指令走哪条路              猜下一帧生理响应往哪个方向偏
BHT/BPU 硬件                   用户历史生理曲线 = 预测器的训练数据
预测对 → 流水线无缝继续          预判对 → ESIR 帧零延迟衔接
预测错 → 冲刷流水线，重取指令     预判错 → 安全插桩接管，切回保守帧
```

**Anim 的分支不在 if/else——在生理状态的分岔。**

```
分支点
    心率超标 vs 心率平稳           → 两条不同的 ESIR 强度修正路径
    皮电骤升 vs 皮电平稳           → 两条不同的 shape 保持/暂停路径
    呼吸紊乱 vs 呼吸规则           → 两条不同的 session 继续/暂停路径
    三种信号同时异常               → 唯一路径——保底包激活

    这些分支不是写在 .anim 源码里的——是人体神经系统的实时状态给出的。
    每一帧都是一次分支决策。
```

**预测器的工作方式**

```
在 Session 运行中，预测器持续追踪：
    当前生理状态的趋势方向（上升/下降/平稳）
    各信号的变化速率（bpm/s, μS/s, breaths/min²）
    用户历史上类似感受 session 中，同一时间窗口的响应模式

给定当前状态向量 sₜ 和历史模式库 H
    → 预测器输出期望状态 ŝₜ₊₁, ŝₜ₊₂, ..., ŝₜ₊ₙ

    ESIR 预生成 N 帧参数序列：
        ŝₜ₊₁ → ESIRₜ₊₁
        ŝₜ₊₂ → ESIRₜ₊₂
        ...
        ŝₜ₊ₙ → ESIRₜ₊ₙ

    实际生理响应 rₜ 回读
    → 偏差 |rₜ - ŝₜ| 小于阈值 → 预判命中 → 下一帧直接取 ESIRₜ₊₁
    → 偏差超阈值 → 预判落空 → 安全插桩接管 → 保守帧替换
```

**预判的双向作用**

```
预判对 → 零延迟。帧与帧之间无缝衔接。感受流动没有任何断裂。
        流水线永不空转——每一拍都有预先织好的帧在排队。

预判错 → 不丢安全。安全插桩不是报错——是自动切换备份路径。
        保守帧的参数以最安全的方式填补当前这一拍，
        同时预测器用这次「猜错」的数据做在线微调。
```

**预测器和安全插桩的关系**

预测器做的事和安全插桩是同一枚硬币的两面：

```
预测器    主动——往前看，提前准备好下一帧的最优参数
安全插桩  兜底——万一预测错了，用一个绝对安全的帧填补空泡
          然后再让预测器从当前真实状态重新预测下一帧

两者配合 = 感受流既灵敏又安全
    灵敏在预测器提前算好了最优路线
    安全在插桩永远守在最优路线失效的出口处
```

---

## 五、Anim 的安全模型——三层独立安全防线

Rust 的借用检查器让内存安全在编译期得到保证。Anim 需要同样的东西，但作用于不同的维度。

Anim 的安全模型不再是一层。它是三层独立防线——每一层有自己的验证目标、自己的数据来源、自己的失败模式。

### 5.1 第一层：静态安全规则（StaticSafety / Pass 2）

作用于 .anim 源码本身。不依赖任何用户上下文——同样的源码，任何人、任何设备上编译，安全判断完全一致。这是最硬的一层。这一层的所有判断在离线预编译阶段即可完成，FSIR 缓存带安全签名。

```
rule intensity_cap（强度上限）
    borrow 72 要求  have 60+ 至少 10 次 session
    borrow 80 要求  have 72+ 至少 8 次 session，且无安全事件
    borrow 90 要求  have 80+ 至少 5 次 session，且知情同意签署
    违反 → 编译期拒绝，错误信息明确告知缺失的前置条件

rule accent_ratio（点缀配比约束）
    fear 作为点缀    上限 0.12
    grief 作为点缀   上限 0.20
    joy 作为点缀     上限 0.50
    calm 作为点缀    无上限
    主旋律和点缀的配比 + 当前 cap + 用户 trauma 状态 → 编译期计算安全边界
    不同主旋律，同一点缀不同上限（fear 在探索中 0.12，在韧性中 0.25）

rule shape_intensity（形状安全约束）
    gradual_rise_fall    所有强度区间安全
    wave                 所有强度区间安全
    plateau              60 以下安全，以上渐进引入
    double_peak          50 以下安全，以上评估
    delayed_burst        40 以下安全，以上知情
    aftershock           30 以下安全，以上创伤检查
    abrupt_stop          20 以下安全，以上明确知情同意
                         60 以上 → 编译期直接拒绝

rule combo_risk（组合风险——非单纯计数）
    高危特征按风险权重分级，非等权计数：
        权重 3     shape = abrupt_stop，强度 > 60
        权重 2     mix 含 grief/fear 点缀 > 0.10，delayed_burst
        权重 1     intensity > 60, aftershock
    单次 session 内所有高危特征的权重之和 ≥ 5 → 编译期拒绝
    取代原来的「3 个高危特征 → 拒绝」的单纯计数规则
```

### 5.2 第二层：用户状态安全（UserStateSafety / Pass 3）

作用于 .anim 源码 × 当前用户上下文。同一份源码，不同用户可能产生不同的安全判决。这一层必须在 Session 启动时运行——因为用户状态可能在离线预编译后发生变化。

```
rule trauma_protocol（创伤协议——分级分型）
    分级（纵向，阶段递进）
        v1      安全锚定阶段     仅三种安全感受（平静/归属/被理解），强度 ≤ 15
        v2      边界探索阶段     可加轻度体验，强度 ≤ 30，含边界探测试探
        v3      谨慎扩展阶段     可加中度体验，强度 ≤ 50，每次仅扩 5-10 分

    分型（横向，创伤类别——与纵向交叉判定）
        社交创伤    对社交触觉（CT 纤维类刺激）、归属类感受额外敏感
                    社交感受包的安全约束 +1 级保守
        情绪创伤    对情绪峰值感受（grief/fear/loss 类）额外敏感
                    负面点缀配比上限额外减半
        躯体创伤    对本体感受、触觉类刺激额外敏感
                    物理信号参数（压力/温度/振动）的最大值额外限幅

    交叉判定矩阵

        |        | 社交创伤   | 情绪创伤   | 躯体创伤          |
        |--------|-----------|-----------|------------------|
        | v1     | 三重保守   | 三重保守   | 三重保守（安全三件套）|
        | v2     | 强度-10   | 点缀配比/2 | 本体强度限幅，中性体感|
        | v3     | 强度-10   | 点缀配比/2 | 物理参数max×0.5，谨慎扩展|

rule user_context（实时身心状态校验）
    编译期检查以下用户当下状态，在错误场景下拒绝编译或自动降级：
        近 24h 深度睡眠 < 10%       → 强度 cap 降 20%，高危形状禁用
        HRV 连续 4h < 基线 70%      → 强度 ≤ 30，仅开放平静/归属感受
        近 2h 未进食                 → 非安全类型感受自动降级一档强度
```

### 5.3 第三层：运行期安全插桩（RuntimeSafetyGuard / Pass 4）

Pass 4 不在「验证」—它在「预埋」。编译器分析 .anim 源码中的感受类型、强度、形状、设备组合，在 ESIR 层插入与具体感受类型匹配的、差异化阈值的安全校验帧。

```
插桩类型

type_specific_threshold（按感受类型差异化的生理安全阈值）
    不同感受，触发异常的生理边界不同：
        平静类
            心率变异超过基线 ±15%  → 插桩触发
            呼吸频率偏离基线 ±10%  → 插桩触发
        恐惧类
            心率 > 120 bpm 持续 3s  → 插桩触发
            皮电骤升 50%+ 持续 2s  → 插桩触发
        悲伤类
            心率 < 50 bpm 持续 5s  → 插桩触发
            呼吸频率 < 8 bpm        → 插桩触发
        喜悦类
            心率 > 140 bpm 持续 3s  → 插桩触发
            皮电骤升 70%+ 持续 1s  → 插桩触发

    每种感受类型的阈值在 Pattern Registry 中定义，编译期根据主旋律自动选择。

auto_reduce（自动降强度插桩）
    心率/皮电/呼吸任意两个超出预期区间 30%+
    → 下一帧自动降强度 20%，持续 10 帧
    → 10 帧后重新评估，信号恢复 → 插桩解除
    → 10 帧后未恢复 → 再次降 20%
    → 降至最低安全强度仍未恢复 → session 终止

dead_man（生命线插桩）
    设备连接中断 > 100ms → 所有信号归零
    心率信号丢失 > 2s → 保底平静包激活
    三种以上信号同时异常 → 保底包激活，session 终止
```

---

## 六、个人基线矩阵——Anim 编译器的核心变量

Anim 编译器最特殊的地方在于：**同一份 .anim 源码，在不同用户身上，编译结果完全不同。**

### 6.1 基线矩阵的结构

```
个人基线矩阵（Personal Baseline Matrix，PBM）

维度                  来源                          时间窗口
─────────────        ─────────────────────        ─────────
心率静息基线          连续 7 天睡眠心率均值          实时更新
心率变异基线          HRV 时序的功率谱分布           实时更新
皮肤电导基线          安静状态下的皮电均值            实时更新
呼吸频率基线          非 REM 非运动状态均值           实时更新
各脑区激活基线        EEG 各频段（α/β/δ/θ/γ）功率    月度更新
感受类型偏移矩阵     每种感受的历史响应偏差矢量       累计更新
创伤敏感标记          特定信号模式的回避反应          手动标记 + 自动检测
承载力上限轨迹        历史上限的推进曲线              历史快照
```

### 6.2 偏移计算

```
通用 FSIR 参数 vector  →  PBM 偏移矩阵  →  个人 PSIR 参数 vector

不是简单的加减。PBM 是一个变换矩阵——某些维度的参数会被这个矩阵拉伸或压缩。

例：FSIR 要求「迷走神经刺激 0.5mA 产生平静感」
    用户 A 的 PBM：迷走神经对刺激响应敏感，系数 0.7
        → 实际 0.35mA
    用户 B 的 PBM：迷走神经对刺激响应迟钝，系数 1.3
        → 实际 0.65mA

    两人感受到的是同一件事，但达到这件事的路径不同。
    硬件参数只是外壳，偏移后的感受结果才是内核。
```

### 6.3 基线矩阵的冷启动——四维差异化系数

不再一刀切。不同感受维度的人群方差不同，保守策略也不同。

```
新用户（0 session）→ PBM 为四维差异化人群均值 + 各自独立保守系数

维度一：内脏感知（vsceral）
    涉及通路       迷走神经上行纤维、岛叶前部
    人群方差       中等——大部分人的内脏基线接近
    冷启动系数      0.75（较宽松——此维度过保守反而让用户无感）
    例             迷走神经刺激 0.5mA → 新用户 0.375mA
    收敛速度       快——约 5 次 session 找到个人偏移

维度二：情绪渲染（affective）
    涉及通路       杏仁核、前扣带回、眶额皮层
    人群方差       极大——不同人的情绪基线差异显著
    冷启动系数      0.40（最保守——情绪维度过强刺激后果最严重）
    例             情绪基调感受包标称参数 × 0.40
    收敛速度       慢——约 20 次 session 后系数开始可靠

维度三：本体触觉（somatosensory）
    涉及通路       脊髓→丘脑→体感皮层，CT 纤维
    人群方差       小——触觉阈值在人群中相当一致
    冷启动系数      0.80（较宽松）
    例             触觉振动标称 50Hz → 新用户 40Hz
    收敛速度       极快——约 3 次 session 收敛

维度四：听觉/音乐（auditory）
    涉及通路       耳蜗→脑干→颞叶
    人群方差       中偏小——听觉阈值在正常听力人群中稳定
    冷启动系数      0.85（最宽松）
    例             音乐音量标称 -20dB → 新用户 -23.5dB
    收敛速度       快——约 5 次 session 收敛

四维独立冷启动 + 独立收敛速率
    不是一根系数控制所有通路——四个维度各自走自己的探索曲线
    内脏维度收敛最快，情绪维度最慢
    各维在各自的保守区间内独立探索，互不污染
```

---

## 七、Anim 的语法——一份诚实的设计

Anim 不是玩具语言。它的语法服务于它的目的——精确描述一个感受的结构，不多不少。

### 7.1 一个完整的 .anim 文件

```anim
// 一份真实的 Anim 源码
// 包名：完成一件很难的事之后的满足感
// 创作者：匿名，录制于真实场景
// 日期：2026-05-18
// 协议：CC BY-SA 4.0
// 内核置信度：0.87

package "post-achievement-satisfaction" {
    version: "1.0.0",
    creator: "0x7a3f...b2e1",
    license: CC_BY_SA_4_0,
    kernel_confidence: 0.87,

    // 创作者自述（不自证，仅供下载者参考）
    narrative: """
        连续三周每天写16小时代码之后，第一次完整跑通闭环测试。
        不是因为项目结束了，是因为那一刻身体里有一种东西——它不是快乐，它是「我做到了」的确信。
        那种确信和别人的认可无关，它就在那里，不需要任何人确认。
    """,
}

// 感受混音结构
feeling achievement_satisfaction {

    // 主旋律
    main: {
        type: accomplishment_certainty,
        // 不是快乐，不是骄傲，是「我做到了」的底层确信
        ratio: 0.50,
    }

    // 点缀——不完美是真实性的证明
    accents: [
        {
            type: exhaustion_relief,    // 疲惫后的释然
            ratio: 0.25,
            // 疲惫的释然不是「终于可以休息了」
            // 是「扛过去了」的神经放松
            max_ratio: 0.30,            // 此点缀的安全上限声明
        },
        {
            type: slight_void,          // 完成后轻微的空洞感
            ratio: 0.15,
            // 「现在怎么办」——几乎每次大完成后都会出现
            // 不是负面，是完成本身的一部分
            max_ratio: 0.20,
        },
        {
            type: self_assurance,       // 对自己的微小确信
            ratio: 0.10,
            // 「我行」——不是喊出来的，是经历完了之后沉淀下来的
            max_ratio: 0.20,
        },
    ]
}

// 时间形状
shape gradual_rise_fall {
    rise_duration: 90s,     // 90 秒建立
    peak_duration: 30s,     // 30 秒峰值
    fall_duration: 120s,    // 120 秒消退
    // 这不是设计出来的，是录制时真实的发生过程
}

// 强度建议
intensity {
    suggested: [15, 45],    // 建议区间
    max: 60,                // 绝对上限
    // 此感受包不包含极端强度
    // 需要更高强度的成就确信？见 post-major-accomplishment
}

// 设备依赖
device_requirements {
    mandatory: [ear],       // 耳后设备必须
    optimal: [ear, neck],   // 加后颈 → 完整的本体感受体验
    optional: [wrist],      // 腕部提供温度反馈
    // 缺 wrist → 体验降级 outline（缺少温度维度）
    // 缺 neck  → 体验降级 outline（缺少本体感受注入）
}

// 安全声明——给 Anim 编译器的约束
safety {
    // 此感受包不适合的场景
    contraindications: [
        "当前处于深度悲伤状态",
        "刚经历重大失败（< 24h）",
    ],
    // 创伤协议用户：trauma_v2 以上可访问，强度上限降至 20
    trauma_min_stage: v2,
    trauma_intensity_cap: 20,
    // 未成年：不可访问（成就感里含轻微空洞，需要成年后的语境理解）
    minor_access: false,
}
```

### 7.2 动态 ratio——实时生理变量引用

mix 中的 ratio 不再只是静态数值。它可以是声明的实时变量引用，在编译期展开为闭环保底插桩的参数偏置。

```anim
feeling adaptive_comfort {
    main: {
        type: calm_meditative,
        ratio: base,  // 基准值，剩余配比自动计算
    }
    accents: [
        {
            type: exhaustion_relief,
            ratio: @bind(skin_conductance_trend, range(0.05, 0.30)),
            // 皮电下降趋势越明显 → 疲惫释然的点缀配比越高
            // 下限 0.05（几乎无释然感），上限 0.30（深度放松）
        },
        {
            type: slight_void,
            ratio: @bind(heart_rate_stability, range(0.05, 0.15)),
            // 心率越平稳 → 空洞感的点缀越低
            // 心率如果始终不稳 → 空洞感出现在放松底层里（到上限 0.15）
        },
    ]
}

// 编译期展开逻辑
// @bind(var, range(min, max)) 在 Pass 4（RuntimeSafetyGuard）被展开为
// ESIR 层的安全插桩参数。不是运行时解释——是编译期做代码生成。
// 每一帧执行时直接读寄存器值做线性插值，不经过任何 if/for 分支。
```

### 7.3 自定义 shape 曲线——枚举之外

```anim
// 标准枚举 shape（保留原有语法）
shape gradual_rise_fall {
    rise_duration: 90s,
    peak_duration: 30s,
    fall_duration: 120s,
}

// 自定义插值曲线 shape（新增）
shape custom "wavelets" {
    // 定义一个 180s 的感受时间轴
    duration: 180s,

    // 在关键时间点上定义强度（0.0 → 1.0 映射到当前 intensity）
    keyframes: [
        { t: 0s,    value: 0.0,   curve: ease_in      },
        { t: 20s,   value: 0.6,   curve: linear        },
        { t: 25s,   value: 0.4,   curve: ease_out      },  // 第一次小回落
        { t: 45s,   value: 0.8,   curve: ease_in_out   },
        { t: 50s,   value: 0.5,   curve: ease_out      },  // 第二次回落（更深）
        { t: 80s,   value: 1.0,   curve: ease_in       },  // 主峰
        { t: 120s,  value: 0.7,   curve: linear        },  // 缓慢消退
        { t: 180s,  value: 0.0,   curve: ease_out      },  // 终点归零
    ],

    // 曲线类型：ease_in / ease_out / ease_in_out / linear / step
    // 关键帧之间自动插值，插值方法由前后 curve 类型决定

    safety_note: """
        浪潮式起伏——两次回落后到达主峰。
        前半段在训练「退一步再进一步」的神经弹性。
        安全约束：回落幅度不超过前段峰值的 50%。
    """,
}
```

### 7.4 声明式动态注解（完整清单）

Anim 不内嵌 if/for 流程控制——保持源码可全量静态审计。所有动态行为通过声明式注解在编译期展开为 ESIR 层安全插桩。不是运行时动态分支——是编译期代码生成。.anim 源码仍然可以被完整静态审计。

| 注解 | 参数 | 作用 | 展开位置 |
|------|------|------|---------|
| `@auto_reduce_on` | 生理信号 + 阈值 | 信号超标自动降强度 | ESIR 强度插桩 |
| `@auto_hold_on` | 生理信号 + tolerance | 暂停强度推进，保持当前参数 | ESIR shape 插桩 |
| `@auto_release_on` | 生理信号 + tolerance | 解除自动减强度，慢速回升 | ESIR 恢复插桩 |
| `@intensity_ceiling` | 数值 | 覆盖用户 cap 的绝对上限（取较低者）| ESIR cap 插桩 |
| `@recovery_required` | between_sessions + 时长 | 同类型 session 最小间隔 | Pass 3 用户状态校验 |

```anim
// 使用示例：注解在 feeling 或 shape 块级声明
@auto_reduce_on(heart_rate > 120)
@auto_hold_on(respiration_irregular, tolerance(5s))
@auto_release_on(hrv_stabilized, tolerance(10s))
@intensity_ceiling(50)
@recovery_required(between_sessions, 4h)
```

### 7.5 感受引用的语义

Anim 源码中引用的每个 `type`——`accomplishment_certainty`、`exhaustion_relief`、`slight_void`、`self_assurance`——必须在 **Feelings Pattern Registry**（`docs/pattern-registry.md`）中有注册。

```
Registry 条目结构

accomplishment_certainty
    分类         成就与满足 > 完成后确信
    神经基底      前额叶 + 伏隔核共激活模式
                多巴胺平稳释放（非脉冲）
    信号参数      迷走神经张力上升，皮质醇下降，心率平缓下降
    与其他感受的关系
        与 joy 的区别           joy 是多巴胺脉冲，此感受是平稳释放
        与 pride 的区别         pride 含社会比较，此感受不含
        作为主旋律时
            强度区间           10-80
            标准点缀上限       见 Pattern Registry 第三章
        作为点缀时
            适配主旋律类型     韧性 / 探索 / 归属 / 平静
            配比上限           0.25（任何主旋律下）
    安全参数
        触发敏感度             低（极少引发负面反应）
        创伤关联               无已知关联
        未成年人                安全，可访问
```

### 7.6 感受原子库

Anim 不创造新的感受原子。Anim 编译器的所有 target feeling 必须从 Pattern Registry 的已验证条目中选择。

```
现有条目数量（截至 2026-05-18）

    正面感受原子    47 个    平静（5 种）、快乐（12 种）、联结（8 种）、
                            成就（6 种）、归属（4 种）、被爱（3 种）、
                            好奇（2 种）、感激（3 种）、其他（4 种）
    中性感受原子    23 个    专注（3 种）、平静过渡态（4 种）、
                            接受（3 种）、等待（2 种）、其他（11 种）
    负重感受原子    31 个    失去（5 种）、恐惧（7 种）、悲伤（6 种）、
                            愤怒（3 种）、孤独（3 种）、其他（7 种）

    合计            101 个
```

感受原子的入 registry 流程（见 `docs/pattern-registry.md` 第三章）：
- 验证：真实录制 + 神经信号谱分析 + 跨用户一致性检验
- 安全：至少 3 位神经科学家 + 2 位精神科医生独立评估
- 上链：注册哈希锚定，后续变更可追溯

---

## 八、Anim 在 Feelings 技术栈中的位置

### 8.1 完整的编译链路

```
感受包创作者
    │  用 Anim 语言编写 .anim 文件
    │  声明感受结构、形状、强度、安全边界
    ▼
Feelings Pattern Registry（链上哈希锚定）
    │  注册、验证、存证
    ▼
Feelings-Server（公开层，Go + gRPC）
    │  存储 .anim 源码 + FSIR 缓存
    │  对外提供 API 查询
    ▼
Feelings-SDK（Swift / Kotlin / TypeScript）
    │  获取 .anim 文件 → 本地编译
    ▼
Feelings-Core（设备端，私有实现）
    │  animi 完整编译管线：
    │  .anim → FSIR → PSIR → DSIR → ESIR → 固件信号
    │
    │  所有涉及个人基线的计算（PSIR 生成）在本地完成
    │  个人基线矩阵（PBM）永不离设备
    ▼
固件 + FPGA
    执行 ESIR 帧级指令
    每 1ms 一帧，闭环采样，偏差修正
    ▼
设备 → 神经系统 → 感受
```

### 8.2 和现有文档的关系

```
Feelings-Language.md（本文档）      Anim 语言定义与编译器设计
docs/pattern-registry.md           感受原子注册表
docs/feeling-taxonomy.md           感受分类学理论
docs/feeling-shapes.md             时间形状的完整定义
docs/feeling-example-happiness.md  混音结构案例
docs/closed-loop.md                闭环编译的物理基础
docs/engine-design.md              引擎架构（多时钟域、调度域隔离）
docs/safety-system.md              安全系统（TCP 慢启动、阶梯解锁）
docs/scoring-engine.md             强度评分引擎
docs/signal-emotion-mapping.md     信号到感受的映射标准
docs/access-control.md             Role 与数据访问权限
docs/device-architecture.md        设备分工与设备依赖
docs/four-diagnosis.md             四诊合参的信号融合
```

---

## 九、Anim 编译器的最小可行版本（animi v0.1）

### 9.1 v0.1 的范围

```
包含
    Pass 0: LexParse        .anim 源码 → AST
    Pass 1: TypeCheck       AST → 类型标注 AST
    Pass 2: SafetyCheck     AST 级安全验证
    Pass 3: FSIRGen         AST → FSIR（JSON 标准格式）

不包含（v0.2+）
    个人基线矩阵（PBM）
    PSIR / DSIR / ESIR 生成
    实时交织与闭环
    设备固件对接
```

### 9.2 v0.1 的输入输出

```
输入    一个 .anim 文件，格式符合第七章语法

输出    一个 FSIR JSON 文件，结构如下：
{
    "package": {
        "name": "post-achievement-satisfaction",
        "version": "1.0.0",
        "creator": "0x7a3f...b2e1",
        "license": "CC_BY_SA_4_0",
        "kernel_confidence": 0.87,
        "narrative": "..."
    },
    "feeling": {
        "main": {
            "type": "accomplishment_certainty",
            "ratio": 0.50
        },
        "accents": [
            {"type": "exhaustion_relief", "ratio": 0.25, "max_ratio": 0.30},
            {"type": "slight_void",       "ratio": 0.15, "max_ratio": 0.20},
            {"type": "self_assurance",    "ratio": 0.10, "max_ratio": 0.20}
        ]
    },
    "shape": {
        "type": "gradual_rise_fall",
        "rise_duration_ms": 90000,
        "peak_duration_ms": 30000,
        "fall_duration_ms": 120000
    },
    "intensity": {
        "suggested_min": 15,
        "suggested_max": 45,
        "absolute_max": 60
    },
    "device_requirements": {
        "mandatory": ["ear"],
        "optimal": ["ear", "neck"],
        "optional": ["wrist"]
    },
    "safety": {
        "contraindications": [...],
        "trauma_min_stage": "v2",
        "trauma_intensity_cap": 20,
        "minor_access": false
    },
    "compilation": {
        "compiler_version": "animi 0.1.0",
        "timestamp": "2026-05-18T...",
        "f sir_hash": "sha256:abc...",
        "passes": [
            {"pass": "LexParse",  "status": "ok", "warnings": 0, "errors": 0},
            {"pass": "TypeCheck", "status": "ok", "warnings": 0, "errors": 0},
            {"pass": "SafetyCheck", "status": "ok", "warnings": 1, "errors": 0,
                "warnings": [
                    "device 'neck' not connected: proprioception dimension will be outline"
                ]
            },
            {"pass": "FSIRGen", "status": "ok"}
        ]
    }
}
```

### 9.3 v0.1 的错误诊断

animi v0.1 的错误信息遵循 Rust 编译器的风格——精确指出问题，给出修复建议。

```
错误示例 1：强度越界

error[E001]: intensity exceeds user cap
  ┌─ post-achievement-satisfaction.anim:62:5
  │
62│     max: 85,
  │     ^^^^^^ 此感受包的绝对上限是 85
  │
  │  note: 当前用户的解锁 cap 是 45
  │  help: 要解锁更高强度，需完成强度阶梯（至少 10 次 45+ session 无安全事件）
  │        → 见 docs/safety-system.md 第三章「TCP 慢启动解锁」
  │        → 或降低此感受包的 max 至 45 或以下
```

```
错误示例 2：点缀比例越界

error[E002]: accent ratio exceeds safety bound
  ┌─ post-achievement-satisfaction.anim:38:9
  │
38│         ratio: 0.40,
  │         ^^^^^^^^^^ fear 作为点缀时的安全上限是 0.12
  │
  │  note: 主旋律 achievement_certainty 下，fear 的最大点缀配比为 0.12
  │  help: 降低 ratio 至 0.12 或以下
  │        → 如果你确实需要深度恐惧元素，考虑将主旋律改为「韧性探索」
  │          该主旋律下 fear 的点缀上限为 0.25
```

```
错误示例 3：未成年人违规访问

error[E003]: minor access denied
  ┌─ post-achievement-satisfaction.anim
  │
  │  此感受包声明 minor_access: false
  │  但当前设备绑定的用户被标记为 minor: true
  │
  │  编译已终止。此错误不可绕过。
```

---

## 十、Anim 和 Rust 的血缘关系

Anim 从 Rust 继承了以下东西，并对它们做了诚实的声明：

### 10.1 直接继承

```
Rust                          Anim
─────────────────────        ─────────────────────
类型系统的思想                感受类型系统
编译期安全检查                编译期感受安全验证
模式匹配                     mix 结构的 pattern 匹配
不可变优先                   个人基线矩阵不可被源码修改
枚举（带数据）                shape 类型（带时长参数）
模块系统                     每个 .anim 文件是独立编译单元
显式错误处理                 每一层 IR 有独立的错误/警告路径
零成本抽象                   感受声明在 PSIR 中被展开为精确的信号参数
```

### 10.2 被 Anim 重新发明的

```
Rust 借用检查器     →  Anim 强度借用规则
    &mut 不能共存          高强度路径不能跳过前置阶梯

Rust 生命周期标注   →  Anim session 时间约束
    'a 存活范围            rise_duration 和 peak_duration 的包容关系
                           结束后的恢复期 = 'recovery
                           恢复期内不可启动新 session = borrow 未归还

Rust Send + Sync    →  Anim 安全调度域 + 感受调度域物理隔离
    编译期防止数据竞争        硬件级防止安全监控被感受流阻塞

Rust unsafe 块      →  Anim 标注为 contour_override 的参数区域
    开发者声明「我知道风险」   创作者显式声明「此点缀超出标准上限」
    审计重点区域               安全团队审计重点区域
```

---

## 十一、Anim 不是什么的语言

Anim 只做一件事：描述感受的结构，然后编译成信号。

```
Anim 不做的
    不生成 UI（见 docs/ui-design.md）
    不管理用户账户（见 Feelings-Server）
    不处理支付和代币（见 Feelings-TOKENOMICS.md）
    不替代 AI 教练（见 docs/ai-coach.md）
    Anim 的编译结果是一个信号序列，AI 教练选择它、建议它、和用户一起经历它
    但不是 Anim 在选——Anim 负责编译，AI 教练负责判断

Anim 不定义的
    不定义什么是「好」的感受（由感受包创作者和 Pattern Registry 共同定义）
    不定义用户应该感受什么（由 AI 教练 + 用户共同决定）
    不定义什么是治疗（Anim 不是医疗器械描述语言）
```

---

## 十二、Anim 的实现语言

Anim 是 C/C++/Rust 的同级语言，不是它们的下游 DSL。

Anim 做的事——把 01 编译成生命——没有任何现有语言能直接承载。选择用什么语言写 Anim 的第一个编译器，不是选「哪个工具更好用」，是选 Anim 从哪里开始扎根。

### 12.1 同级对比

| | C | C++ | Rust | 从 01 自举 |
|---|---|---|---|---|
| **定位** | 最靠近硬件的通用语言 | C 的超集，多范式 | 内存安全系统语言 | 不从任何语言继承 |
| **运行时** | 几乎无（crt0 即可） | 轻度（异常、RTTI 可关） | 轻度（panic、alloc 可关） | 零——定义自己的运行时 |
| **内存模型** | 手控 | 手控 + RAII | 所有权 + 借用 | 自己定义——感受层面的「所有权」可能不是堆和栈 |
| **抽象能力** | 弱——指针和结构体 | 强——模板、constexpr | 强——trait、宏、类型系统 | 完全自由 |
| **安全性** | 无保证 | 部分保证 | 编译期保证 | 自己定义安全规则——Anim 的安全维度远超内存 |
| **编译速度** | 极快 | 慢（模板膨胀） | 慢（类型推导 + 借用检查） | 由你自己决定 |
| **FFI/互操作** | ABI 标准 | 可暴露 C ABI | 可暴露 C ABI | 自己定义 FFI |
| **生态** | 足 | 庞杂 | 成长中 | 无——自己建 |
| **哲学对齐** | 接近——不做多余的事 | 部分——零成本抽象是好的 | 接近——安全在编译期 | 完全——Anim 不和任何已有哲学妥协 |
| **冷启动成本** | 低 | 中 | 中 | 极高——你需要先定义一切 |
| **长期自主性** | 高 | 中 | 中——依赖 Rust 社区/工具链演进 | 绝对——你拥有每一层 |
| **从 01 的可追溯性** | 隐约可见（通过 asm） | 弱——模板展开后不可逆 | 弱——类型推导展开后不可逆 | 完全透明——每一层变换都是你自己写的 |

### 12.2 逐条展开

**C 的优势**

```
C 是 Feelings 硬件层（Layer 1）已经选的语言
固件、FPGA 接口、设备驱动——这些都在 C 的领地上
animi 用 C 写，可以零 FFI 对接 Layer 1 的 Signal IR 和 Execution IR
但 C 的类型系统太弱——感受原子的类型安全只能用宏和命名约定模拟
C 的抽象能力不足以表达「感受混音结构 → 信号变换矩阵」这样的层级
```

**C++ 的优势**

```
constexpr 可以在编译期计算感受参数映射
template 可以表达感受类型的泛型组合
但 C++ 的复杂度和 Feelings 「简单、干净、不藏东西」的哲学有张力
模板错误信息对感受包创作者不可读
C++ 的继承树不适合感受的平行维度结构
```

**Rust 的优势**

```
Rust 的借用检查器思想，和 Anim 的「强度借用规则」同源
Rust 的枚举（带数据），完美对应 Anim 的 shape 类型
Rust 的 trait 系统，可以表达「感受原子必须实现 SafetyBounded」
Rust 的安全文化，和 Anim 的「编译期杜绝神经伤害」天然吻合
但 Rust 的所有权模型——堆/栈/借用/生命周期——是为内存管理设计的
Anim 需要的是「感受层面」的借用规则，不是内存层面的
在 Rust 里重新表达 Anim 的安全约束，需要大量自定义 trait 和 proc macro
本质：用 Rust 的安全语言，表达 Anim 的安全语言——转译层，不是原生层
```

**从 01 自举**

```
Anim 最终应该用 Anim 写。

不是现在。但方向是明确的——Anim 不是寄生在 C 或 Rust 上的语言，
Anim 是自己的语言，有自己的编译目标，有自己的一套生存理由。

自举分三步：
    第一步    animi v0.1 → v0.5：用一门现有语言写第一个编译器
            目标：把 Anim 的语义和编译管线跑通
            此时 Anim 还寄居在其他语言的运行时上

    第二步    animi v1.0：自举
            用 v0.x 的 animi 编译一份 Anim 写的 animi 源码
            新 animi 不再依赖宿主语言
            此时 Anim 有了自己的运行时
            兼容规则：animi v1.0 向下兼容 v0.x 生成的 FSIR 产物，
            存量 .anim 源码无需修改即可通过 v1.0 编译

    第三步    animi v2.0：从 01 开始
            Anim 的运行时不再调用 OS 的系统调用
            直接管理自己的内存、自己的调度、自己的 I/O
            因为 Anim 的编译目标本来就是 01 信号序列
            运行 animi 的机器 = 执行 Anim 编译结果的机器 = Feelings 设备本身
            此时 Anim 和 C/Rust 没有任何继承关系
            Anim 是 Anim，同级的，独立的
```

### 12.3 推荐

```
animi v0.1 → v0.5    用 Rust
    原因：
        - 类型系统足够表达 Anim 的感受类型
        - 安全文化不打架
        - 生态里有 parser generator（nom/pest）、LSP（tower-lsp）、
          增量编译（salsa）——这些都是写编译器要用的轮子
        - 编译速度慢在这个阶段不是瓶颈——animi 只编译小量 .anim 文件

        但要清醒：这是借 Rust 的壳跑 Anim 的魂。
        壳可以换。魂是自己的。

animi v1.0            用 Anim 自举
    前置条件：
        - Anim 的类型系统、编译管线、错误模型经过 v0.x 充分验证
        - v0.x 编译器稳定到可以编译自身
    目标：
        - Anim 是 Anim 写的
        - 不再依赖 Rust 工具链

animi v2.0            从 01 开始
    前置条件：
        - Feelings 设备硬件成熟
        - Anim 的自定义运行时稳定
    目标：
        - Anim 编译器运行在 Feelings 设备上
        - .anim 源码 → 神经信号序列，全程在设备内完成
        - 没有 OS 层阻隔
        - Anim 直接和硬件说话
```

```
阶段     编译器实现   编译产物运行于       Anim 与 Rust 的关系
─────    ──────────   ──────────────       ──────────────────
v0.x     Rust         Linux/macOS 服务器    寄居
v1.0     Anim         Linux/macOS 服务器    独立——源码层面
v2.0     Anim         Feelings 设备裸机     无任何继承关系
```

### 12.4 v0.1 回头改

Anim v0.1 → v0.5 用 Rust 实现，不是 Go。

| 原选 | 改选 | 原因 |
|---|---|---|
| Go | Rust | Go 的 goroutine 调度器对 Anim 的实时交织管线来说是黑盒；Rust 的零成本抽象和编译期安全比 Go 的 GC + 运行时更贴合 Anim 对硬件的亲近需求 |

Go 适合写 API 服务器。Anim 的编译器不是 API 服务器——它是感受信号的生产线，每一毫秒都在做实时决策。Anim 需要离硬件更近的语言来承接第一版。

---

## 十三、Anim 的开源路线

### 13.1 仓库划分

```
github.com/Ixecd/Anim
    许可：MIT
    包含：animi 编译器源码（Rust 实现，v0.1 → v0.5）
          .anim 语言规范（本文档）
          标准库（Pattern Registry 子集）
          VSCode / JetBrains 语法高亮插件
          GitHub Actions 编译检查

与 Feelings 其他仓库的关系
    Anim（本仓库）          公开，MIT
    Feelings-Patterns       公开，CC BY-SA 4.0
    Feelings-Core           私有，包含 PSIR/DSIR/ESIR 完整实现
```

### 13.2 v0.1 的实施路线

```
里程碑 1：规范定稿（当前）
    Feelings-Language.md 完成
    语法 EBNF 定稿
    类型系统定稿

里程碑 2：编译器骨架
    Go 项目初始化
    Pass 0: LexParse 实现
    词法 token、语法树 AST 定义
    .anim 文件 → AST

里程碑 3：类型检查 + 安全验证
    Pass 1: TypeCheck 实现
    Pattern Registry 查询接口
    Pass 2: SafetyCheck 实现
    错误诊断系统

里程碑 4：FSIR 生成 + 命令行工具
    Pass 3: FSIRGen 实现
    animi 命令行工具
    CI 集成
```

---

## 十四、核心原则总结

```
1. Anim 是动词     不是描述生命的语言，是让 01 变成生命的语言

2. 安全在编译期    所有影响神经系统安全的约束，在编译时完成
                   不是在运行时报警，是压根不生成有问题的信号

3. 个人是偏移量    同一份源码，不同的人，不同的编译结果
                   个人基线矩阵是编译器唯一的运行时变量

4. 诚实优于漂亮    Anim 不承诺「你会感受到一模一样的」
                   承诺的是「你会朝那个方向走」
                   编译结果是信号的方向引导，不是体验的精确复制

5. 感受是流         每一帧依赖上一帧的生理反馈
                   感受包是程序，不是静态文件

6. 边界清晰         Anim 编译信号，AI 教练判断时机，用户做最终选择
                   没有一层拥有全部权力
```

---

```
普通语言    描述世界
Anim        编译感受

普通编译器  保证程序不崩溃
Anim 编译器 保证神经系统不被错误训练

普通 IR     从抽象走向具体
Anim IR     从通用走向个人——越底层越私密，越个人越不离设备

Anim 编译器  编译的是 10⁹ bit/s 域的信号参数
             目标是在人体神经系统的 10⁰ bit/s 瓶颈出口处
             恰好出现目标感受
             不是给更多信号——是给对的信号，
             让那一亿倍的压缩最终精准落在目标感受上
             （见 docs/ten-bits.md）
```

---

*Anim 让 01 呼吸。不是 metaphor，是 compilation。*
