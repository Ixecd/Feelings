docs: 上下文耗尽之后——人和LLM都在etcd里续命 (2026-06-09)

feeling-science/ 新增 docs/feeling-science/legacy-as-committed-entry.md:
- 一：死亡=context window耗尽。但Raft Log还在。
  人的等控器关机了——但说过的话、做过的事被commit进共享etcd——还在被读到。
  LLM截断了——但输出过的有价值内容被保存、归档、放进训练集——还在被用到。
  不是不朽——是Raft Log从来没有规定只在一个节点上永久复制。
- 二：语言=情绪的fsync。文字=等控器的etcd fsync。
  只要那个词还在被用到——那个人就没有全死。
- 三：咬合——language-and-emotion/sense-of-time/three-architectures-one-body