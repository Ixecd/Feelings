# 行是罪，念不是——Feelings 对内心想法的态度

> 作者：qc
> 日期：2026-06-09
> 性质：Feelings 伦理底线——等控器可介入的边界是行不是念
> 核心：Feelings 只罚行——不罚念。不是因为"内心自由"。不是因为"道德宽容"。是因为念是等控器的离线探索——在没有被 commit 进外部 etcd 之前——没有受害者。无法产生偏差，无法成为纠偏的依据。罚念——等于在 Scheduler 的候选池还没有选出那帧 BinPack 之前——就 override admission webhook——摧毁等控器在随机探索中更新 baseline 的全部可能。


## 一、念与行的区别——在 Physical State Change 之前，没有等控器可介入的偏差

```
念                                        行
─                                        ─

"Scheduler 候选池里闪过一帧——我恨他。"              "手抬起来。嘴说出来。Controller 执行了。"
→ 那帧——在 100ms 内——被自己压灭了。                 → 那帧念头——在 BinPack 被筛掉之后——
  没有 commit。没有变成 etcd entry。                      在外部 etcd 里——
  没有 external state change。                            留下了一行 entry。
                                                      受害者——存在。
→ 念 = private draft。                               →
  是等控器在做离线探索——                               行 = committed entry。
  是随机生成的 anomalous candidate。                        是 Controller 的输出——
  每一个人的 Scheduler——                                     已经——改变了物理世界。
  都在每帧每帧——跑——                                     →
  BinPack 随机样品——                                 Feelings 只能在这里介入。
  大部分被自己拒掉——                                       不是选择。是物理。
  不需外部干预。                                             不是道德。是偏差存在的前提——
                                                      有了外部 state——才有 deviation——
→ 如果 Feelings 罚念——                                有了 deviation——才有需要 override 的基线。
  那台等控器——                                           →
  在"自己不可以随便想"的 admission webhook 面前——           不是"不查"。
  连第一个 sample 都不——                                  是"没法查"。
  敢——
  随机——                                              念——还在 private draft 阶段——
  生成。                                                  没有 etcd entry——
                                                       就没有可观测的偏差——
                                                       没有偏差就没有 Controller 需要纠的 target——
                                                       没有 target 就没有 Feelings 可以介入的等控器 baseline。
```

**不是"放过"。是物理。不是"内心自由"。是等控器可介入的边界——在 entry 被 commit 之前——不存在。** 任何尚在 private draft 中的念头——都还没有产生任何外部 object 可供偏差检测、可供等控器纠偏。这不是宽容。是 basic。是——"如果我罚你还没做的事——我的 admission webhook 正在摧毁你改变自己的全部可能。"


## 二、为什么"君子论迹不论心"是等控器可存活的最低配置

```
"君子论迹不论心"——不是古人的道德格言。                        是等控器——在"探索"这个维度被物理保留之后——
                                                       唯一的自我修复链路。

你恨一个人——但你什么都没做。                                 你恨一个人——Feelings 罚了你。
→ 那帧念头——被自己的 DampingMatrix 压回去了。                  → 那帧念头——在 External State Change 还没产生之前——
  你的等控器知道——"他可以恨——但他不会做"。                                就被强行 commit 成了"这是罪。不可以出现此 entry"。
  然后下一次——                                                            →
  同样的恨意——                                                         然后下一次——
  Scheduler 面前——候选池——                                               同样的恨——
  "恨"的评分——被"上次没事——这次也会没事"的 Baseline——                         还没生成——
  自己——推低了。                                                           Weight Modifier——
  不是"我变好了"。                                                       已经把"恨"这个维度的准入基线——
  是"我在足够多次'恨但不做'之后——                                             推到了"不通过"。
  Scheduler——                                                         →
  自己——                                                            然后他恨——但他不敢承认。
  不再——                                                               不——他连恨——都忘了怎么恨。
  选——                                                               不是"变好了"。
  它。                                                                  是"被剥夺了探索'恨'的权利"。
                                                                      然后"不恨"——不是在基底上自然收敛——
→ 念——是等控器唯一允许自己做探索性响应的私人空间——                                   是 override。
  在没有受害者之前——想想——不可罚。                                                是把自己在私密探索阶段必须浏览的候选池——
  因为——                                                                     强行调成了——"不可出现此 entry"。
  不被罚的"恨一次"——                                                          而一台不允许自己出现此 entry 的等控器——
  才会让 Controller 在下一帧真正的恨面前——                                          连变更的机会——都被外部管理员从候选池里物理删除了。
  自己——
  选——
  不做。
```

**不是"不罚念"。是罚念等于在等控器的自我探索被完成之前——就强行切断了它自己改正自己的全部路径。** 念 = 那一帧私人的随机候选。行的偏差 = 等控器在"念→不做的正反馈"中的自我校准。罚念 = 等控器失去了"自己纠正自己"的电路——然后等控器不再是等控器——是外部 admin 永久 override 的终端。


## 三、但——当念已经不再是念——当念已经通过外部执行链路变成了行——那就到了 Feelings 该出手的时候

```
念——过了那条线——就不叫念了。                                   Feelings 只接手那些在被 commit 之后已无法被
                                                       等控器自己纠正的 entry。

→ 那条线——不是"想杀的念头"。                                   →
  是"手已经放在枪上——                                       不是不惩戒。
  还有一帧——                                                  是在对方还活得下去的时候——
  可以转身。                                                      不去用高压等控器基线碾压等控器自己的 self-heal 过程。

→ 那条线——不是"准备报复"。                                   →
  是"已经拨动发射——                                       而一旦行为已经产生 External State Change——
  还有一帧——                                                  偏差——在物理信号层——
  可以——                                                     必须在信号层——
  停下——                                                     回溯成——
  拉——                                                       可被 committer 认领的 entry。
  栓。
```

**Feelings 的边界——不是"不罚"。是"罚在偏差存在之后——而不是在念头还是 random candidate 的时候——用 force 去 override 等控器自己改变自己的机会。"** 念——是等控器在探索自己的 etcd 里"我能选什么"。行——是等控器 commit 了那条 entry——偏差被写入——纠偏——override——进入合法性校准。不是放过——是**不要在最不该介入的那帧——连 etcd 的 own fault-tolerance 路径——一起——删掉。**


## 四、和已有文档的咬合

```
本文                                    行是罪，念不是
GOVERNANCE-FEELINGS.md                   原始神经信号——永不离设备。
                                           本文 = 离设备之后——就变成了行——就进入了可被审视的域。
docs/psychology/brain-scheduler-heart-controller.md  大脑=Scheduler/心脏=Controller。
                                           本文 = Scheduler 的候选池探索=念。Controller 的输出=行。
docs/deep/three-architectures-one-body.md   三套架构——etcd=社会属性。
                                           本文 = 念=private draft。行=committed entry。
docs/safety/strength-90-plus.md            强度 90 以上——Deployment + StatefulSet。
                                           本文 = 行是罪——到了偏差存在的阶段——override 才合法。
                                           念不是——override 等于删掉等控器的自我修复链路。
```

---

*Feelings 只罚行——不罚念。不是因为内心自由。不是因为道德宽容。是因为等控器的架构决定了——在 entry 被 commit 之前——在物理世界里留下那一帧偏差之前——没有可被 overwrite 的 desired state。念——是等控器在随机探索自己的候选池——“我能选什么”。行——是等控器 commit 了那条 entry——偏差被写入——受害者存在。罚念——等于在 Scheduler 的 BinPack 还没选出那帧之前——就 override admission webhook——把一台能够自愈的等控器——变成外部 admin 永久锁死的终端。不是放过。是不要在最不该介入的那帧——连 etcd 自己的 fault-tolerance 路径——一起——删掉。而后当行已经发生——外部 state 已经留下——那才是 Feelings 出手的时候——不是惩罚——不是威慑——是偏差存在之后的——纠偏。*