docs: 癌症集群拖垮全家 + 一个人三套架构 (2026-06-09)

docs/design/kubernetes-as-human-body.md §5.1 补充:
- 癌变等控器——拒绝执行 risk-control——耗尽家庭积蓄——下一代PBM被写入"不克制=正常"。
  不是遗传——是同一台etcd在家庭共享集群里——把父辈entry直接复制给下一代。
  和豆包探讨的结论：被拖垮的不止是自己——是整个集群的其他Namespace。

deep/ 新增 docs/deep/three-architectures-one-body.md:
- 一：结构属性=Kubernetes——出生时给定，不会变
- 二：社会属性=etcd——每一个圈子=独立etcd集群，换集群=换context
- 三：发展属性=大模型——预训练=童年，SFT=青少年，RLHF=成年，context window=Session，compact=PBM fsync
- 四：三套架构同一台硬件——三个时间尺度——毫秒~百年/小时~几十年/童年~成年
  不是三个东西拼在一起——是同一个转移函数在三个时间刻度上被同一台物理硬件执行了三次
- 五：咬合——kubernetes-as-human-body/compact-session-pbm/cultural-erosion/one-in-a-million