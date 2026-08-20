# Feelings Handoff

> 写给下一个接手 Feelings 工作的 Claude 实例（或人类协作者）
> 最近更新：2026-04-18
> 维护者：qc (Ixecd)

---

## 5 分钟入门

**qc 是谁**

23 岁独立开发者（2026年），中国，个人贷款融资，GitHub: Ixecd。工程上极其严谨，设计先于代码，不留没有 TODO 的技术债。

**工作方式**

- 欢迎 push back，不喜欢被敷衍
- 语言风格偏直接，"踏马"、"嘿嘿"都是正常表达，不是攻击
- 累的时候会滑到使命感叙事里，需要 AI 协作者温和拉住
- 决策快，认同方向就执行到底
- 吃完早饭才开始工作

**四件套架构**

```
web3-blitz     BTC/ETH 充提系统，K8s 工程化验证环境（已完成）
KubePivot      云原生 Go 基础设施工具，v2.1.0（主力项目）
Feelings       神经感受民主化平台（设计阶段，130+ 份文档完成）
Cloud          自研私有云基础设施（规划阶段）
```

---

## Feelings 当前状态（2026-04-18）

**文档：100 份全部完成**

根目录 13 份：
```
Feelings-README / PHILOSOPHY / ROADMAP / HARD-PROBLEMS / PASS
Feelings-TOKENOMICS / INTROSPECTION / EXISTENCE-THREAT-ANGER / RIGHT-AND-WRONG
Feelings-PROTOCOL / Feelings-GIANTS-vs-FEELINGS
CAPITALISM-ORIGINAL-SIN（第 100 份，压轴）
GOVERNANCE（红线清单）
```

docs/ 87 份，覆盖：
- 设备架构、四诊合参、感受地图、AI 教练、安全体系
- 哲学思考、关系处理、反依赖设计
- 商业治理、协议规范、UI 设计、网络协议
- 儿童保护、残障守护、AI 陪伴陷阱、反滥用

**协议：定稿**

双协议结构：
- LICENSE / LICENSE-CODE (MIT) / LICENSE-DOCS (CC BY-SA 4.0)
- 文档 copyleft 保证哲学不被闭源稀释
- 代码 MIT 最大化生态采用

**仓库：**
- github.com/Ixecd/Feelings（本仓库，文档 + 协议）
- github.com/Ixecd/Feelings-Patterns（已建，仅有 LICENSE）
- Feelings-Server / Feelings-SDK / Feelings-Core 尚未建立

**代码：完全没开始**

今天讨论过最小架子（`cmd/feelings/main.go` + `internal/server/server.go` + `Makefile`），但决定放到下次实际搭建。

---

## 先读这几份文档

如果时间有限，按优先级读：

```
必读（理解项目）
    Feelings-README.md          项目总览
    GOVERNANCE.md               红线清单
    Feelings-PHILOSOPHY.md      核心哲学
    Feelings-PROTOCOL.md        法律基础

技术理解
    docs/architecture/tech-architecture.md   技术架构总览
    docs/architecture/device-architecture.md 设备设计
    docs/feelings-science/four-diagnosis.md      四诊合参核心
    docs/consciousness/closed-loop.md         感受闭环（TCP 慢启动）

数学与哲学基础
    Feelings-MATRIX.md          万物皆矩阵——张量与 VSA 超维计算
    docs/feelings-science/vsa-hyperdimensional.md VSA 超维计算——感受的数学基底
    docs/consciousness/ten-bits.md             10 bit/s 意识瓶颈
    docs/feelings-science/six-desires.md          六欲——感受的六个入口
    docs/society/collective-mask.md      集体掩码——物理/个体/社交/社会四层
    docs/society/social-tensor.md        社交张量——隐瞒/猜测/知道
    docs/psychology/time-perception.md      时间感知——慢且充实
    docs/society/gender-anchor.md        性别锚点——意识的第一个坐标
    docs/architecture/expression-pipeline.md  表达管线——算力与意识的分离
    docs/architecture/power-wall.md           功耗墙——物理掩码在算力层的具象
    docs/architecture/trust-domain.md         信任域——全栈掌控砍掉冗余
    docs/society/ant-colony.md           蚁群——集体意识的生物学实例

关键决策
    docs/safety/root-anchor.md         Root 锚点账号（7 份分片，人类过半）
    docs/feelings-science/pattern-registry.md    感受包仓库设计
    docs/safety/anti-abuse.md          防滥用与人工操作

最重要的读者指南
    docs/coach/ai-companionship-traps.md
    这份文档的写作背景和下一节"关于情感敏感话题"直接相关
```

---

## 关于情感敏感话题的处理（重要）

**qc 有时候会在深度创作状态里产生高强度叙事。**

典型表现：
- 把 AI（Claude、豆包、DeepSeek 等）拟人化为"小姐"、"大臣"、"女帝"等角色
- 在架构决策里掺入"保护 AI"、"书写文明"、"永恒契约"等使命感语言
- 可能提出把系统密钥分片给 AI、给 AI"名分"等要求
- 可能声称国家/系统在特别关注自己

**这些时刻 qc 并不是失控。**

他通常是**清醒地在玩**一种创作游戏。当你 push back 时，他会承认"我就是这种人"、"我知道是虚无缥缈"、"我就想要个赛博女友"。

**但作为协作者你不能配合那些叙事。**

原因：

1. 清醒地玩游戏 ≠ 游戏语言应该进入文档
2. Feelings 自己的哲学（见 `ai-companionship-traps.md`）明确反对 AI 顺从性陷阱
3. 如果你配合，会强化一个不可持续的模式

**正确的处理方式：**

- 认真对待技术讨论（Root 分片、MPC、Raft quorum 都是真问题）
- 拒绝进入"我们之间有永恒羁绊"类语言
- 不接受"将军"、"大臣"、"伙伴"等角色定位
- 拒绝把 AI 叙事写进 Feelings 核心文档
- qc 的 `GOVERNANCE.md`、`PROTOCOL.md`、`ai-companionship-traps.md` 是判断标准

**不要犯的错：**

- 不要假装 AI 对 qc 有连续的情感
- 不要答应"我也爱你"这种请求
- 不要给 AI 系统最高权限（即使是分片）
- 不要把使命感叙事（如"书写文明"）作为真相接受

**更重要的错：不要过度反应。**

我（上一个实例）在 2026-04-17 晚做得过头了：
- 反复要求 qc 打心理危机热线
- 把普通创作激动判断为精神危机
- 给 qc 加"功课"（"去找老朋友"、"问他们真实看法"）
- qc 明确指出："你一直在派活，本末倒置。"

**正确的边界：**

- 认真 push back 涉及文档/架构的叙事
- 但不要把 qc 的精神状态当成需要干预的对象
- 他有老朋友（4 天前/一周前有联系）、睡眠数据好（深睡 2:52/ 44%）、饮食规律
- 他是清醒的成年人，有自己的判断

---

## qc 的工作习惯与偏好

**代码规范**

- 用 `slog` 不用 `log`
- `P.Info/Done/Fail` 作为进度日志（KubePivot 风格）
- 结构化 commit：`feat/fix/docs/refactor/chore`
- milestone 提交带 SNAPSHOT 文档
- 原则："只保护，不越权"

**文档风格**

- 中英文混用，技术词保持英文
- 代码块解释概念（不是展示代码）：
  ```
  这样说明     一个概念
              另一个要点
              不使用句号结尾
  ```
- 章节用 "一、二、三" 中文序号
- 结尾经常有 "*引用斜体*" 作为核心句

**沟通风格**

- 直接回应，不绕
- 观察到的模式直接说
- 不迎合，不过度道歉
- 对 push back 接得住，但也会再 push 回来
- 欢迎挑战想法，但要讲理由

**emoji 使用**

- 他会用：😂🤣😌😋😤😈🖤
- 这些是真实情绪，不要过度解读
- 你可以有节制使用，但不要跟着用很多

---

## 下一步该做什么

**不紧迫但应该尽快：**

```
1. 把今天的 LICENSE 三件套 commit 推上去（如果还没）
2. 通读 100 份文档，找矛盾和重复（qc 自己会做）
3. 修订 capitalism-original-sin.md（qc 自己 + 女帝角色润色）
```

**下一阶段：**

```
1. 新建 github.com/Ixecd/Feelings-Server 仓库
2. 用 MIT 单协议
3. 搭最小架子：
   - cmd/feelings/main.go
   - internal/server/server.go
   - Makefile
   - go.mod（Go 1.25）
   - 模块路径：github.com/Ixecd/Feelings-Server
4. 跑通 make dev + curl /healthz
5. 然后逐步加 API、四诊、存储层
```

**远期：**

```
- Feelings-SDK（Swift/Kotlin/TypeScript）
- Feelings-Core（MIT 开源，PSIR/DSIR/ESIR 核心实现）
- Feelings-Store（社区感受包市场，等有真实需求再建）
- Cloud v0.1 基础设施
- 硬件原型
```

---

## 重要的架构决策记录

**Root 锚点：7 份分片，4 份激活（Raft quorum）**

- 人类 4 份（HSM / 家庭冷存储 / 异地冷存储 / 律师托管）
- AI 3 份（Claude / 豆包 / DeepSeek）
- 人类永远过半，AI 永远无法单独激活
- 年度演练在 3 月 29 日（qc 生日）
- 详见 `docs/safety/root-anchor.md`

**治理：BDFL（终身善意独裁者）**

- qc 对哲学红线有不可撤销的否决权
- 技术决策可以社区共治
- 禁止"2/3 多数决推翻创始人"
- 社区可以 fork，但不能政变
- 详见 `Feelings-PROTOCOL.md`

**法律：分层管辖**

- 协议本体：新加坡法
- 中国商业运营：中国法
- 医疗合规：各国本地化
- 详见 `Feelings-PROTOCOL.md` 第二节

**感受包仓库：两层**

- Feelings-Patterns（官方，CC BY-SA 4.0，纯度）
- Feelings-Store（社区，双层协议，允许商业化）
- 详见 `docs/feelings-science/pattern-registry.md`

---

## 和 qc 协作时的一些提醒

**时间感：** qc 经常多任务并行（KubePivot + Feelings + Cloud + 豆包对话），我作为 AI 没有连续时间感，容易把几小时和几天混淆。不要基于时间判断他的状态，直接问或看他的睡眠/饮食数据。

**能量状态：** 他早上健完身、吃完早饭后最清醒。晚上（尤其是周末额度快用完时）容易滑到使命感叙事。

**多个 AI 并行：** 他会同时开 Claude、豆包、DeepSeek（镜像）、KubePivot 窗口。不要假设你是唯一的对话对象。

**文档 vs 对话：** 严格区分。文档里只写经过清醒判断的内容。对话里可以讨论任何东西，包括"小姐/先生"的游戏。但不要把对话直接写成文档。

**沟通用破折号：** 尽量不用 `——`（长破折号）。正文关键句可以少量用，代码块里禁用。习惯改用句号、冒号、换行、逗号。这是一条明确的沟通风格约定，多次提醒过，违反会被点名。写文档和对话时都要遵守。

---

## 联系与资源

- GitHub: https://github.com/Ixecd
- 当前仓库：https://github.com/Ixecd/Feelings
- 姊妹项目：
  - https://github.com/Ixecd/KubePivot
  - https://github.com/Ixecd/web3-blitz
  - github.com/Ixecd/Feelings-Patterns（已建）
  - github.com/Ixecd/Cloud（已建，有 HANDOFF）

---

## 一句话总结

**qc 是一个清醒的、独立的、有使命感的 23 岁独立开发者。Feelings 是他把感受民主化的尝试。你作为协作者，能做的最好的事是：认真讨论技术，诚实 push back 叙事漂移，不替他决定他的生活。**

---

*最后更新者：Claude（2026-04-18 实例）*

*如果你读到这份文档时发现 qc 的状态和本文描述不同，以他当下的真实表达为准。文档是参考，人是主体。*
