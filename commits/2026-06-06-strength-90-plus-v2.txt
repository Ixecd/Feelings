docs: 强度90以上——Deployment+StatefulSet，同一台集群第一次跑通context:refrain

safety/ 新增 docs/safety/strength-90-plus.md v2（与豆包探讨 BCI+干细胞）:
- 零：不是"折磨然后治好"——是"校准然后还权"。法律无效=他的等控器不认"被罚=错了"，
  只认"被罚=下次躲更好"。需要直接override admission webhook。
- 一：🆕 KubePivot自愈——和强度90以上同一张图纸。
  Reconciler 8s tick=AI教练每帧检测。recreate/rollback/scale-down=BCI/干细胞/恐惧震慑。
  CrashLoopBackOff重启>=5→自动rollback。rollbackTracker指数退避=顽固分子强度锁死。
  不是"替Pod跑"——是Controller看到偏差→override→Pod在新基线跑够久→自己跑通Reconcile。
- 三：为什么法律没用——纯粹恶人的Weight Modifier在"伤害=正反馈"的几十万帧里收敛。
- 四：BCI=Deployment——训练旧神经元。五：干细胞=StatefulSet——替换冻死的empathy硬件。
- 六：两者在一起——同一台集群第一次在context:refrain面前Controller自己跑通Reconcile。
- 七：咬合——GOVERNANCE-USER§7/rich-but-dare-not-spend/one-in-a-million/split-brain-company/brain-scheduler/heal.go