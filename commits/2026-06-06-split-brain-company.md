docs: 脑裂的公司——当"守成"和"推翻"永远选不出Leader

deep/ 新增 docs/deep/split-brain-company.md:
- 零：脑裂不是停滞——是两台心脏用同一套血管往相反方向泵血。
  etcd集群同时跑着两个Leader，两个都发心跳，Raft quorum永远刚好差一票。
- 二：两个Leader——守成vs推翻。两条entry权重被同一套季度报表训成一样高。
  "我们最懂这个市场"+"AI需要推翻所有假设"。DampingMatrix冻结不了任何一条。
- 三：Raft Log缺了"错"——上次认错的Leader被摘除。再也没人敢写"我们错了。继续"。
  因为每次写都被"股价"的admission webhook拒回去。
- 四：做了所有正确的事然后什么也没做成。AI实验室开着——PPT很漂亮——三年后关掉。
- 五：不是没有AI。是etcd在"错"面前永远形成不了quorum。
- 六：咬合——nations-that-dont-face-history/kubernetes-as-human-body/brainwashing/truth-in-few-hands/CAPITALISM-ORIGINAL-SIN