# taVNS 临床证据——技术成熟度的背书与"证明有效"的边界

> 作者：qc
> 日期：2026-08-25
> 性质：Feelings 科学依据，耳部经皮迷走神经刺激（taVNS）临床数据清单
> 核心：taVNS 已有数百项临床试验和几十项 Meta 分析，技术成熟度不用再被质疑。但证据有边界：安全性强（无严重不良事件），有效性真实但证据等级偏低（low to very low）。"技术成熟"只证明原理站得住，"你的产品有效"必须自己做。临床数据全部以 PMID 透明引用，Feelings 开源，证据链可审计。

---

## 零、先定前提

Feelings 的靶是迷走神经耳支（Arnold）。tVNS 的技术成熟度不是 Feelings 自己声称的，是公开临床证据堆积出来的。这份清单有两个作用：把"技术成熟"从口号变成可审计的事实；同时划清"技术成熟"和"产品有效"之间的边界。

---

## 一、临床证据地图（随机对照试验）

```
神经/精神
    慢性失眠           JAMA Netw Open 2024        PMID 39680406
                       大样本 RCT，taVNS 显著改善失眠
    卒中后抑郁         J Affect Disord 2024       PMID 38452937
                       双盲安慰剂对照
    难治性癫痫         Neurotherapeutics 2023     PMID 36995682
                       150 例随机双盲
    轻度认知障碍       Brain Stimul 2022          PMID 36150665
                       双盲 RCT

自主神经/心脏
    房颤（TREAT AF）   JACC Clin EP 2020          PMID 32192678
                       耳屏低强度刺激抑制房颤
                       → 迷走对心脏的直接影响，Feelings 测量信号的源头

炎症/免疫
    SLE 疼痛/疲劳      Ann Rheum Dis 2021         PMID 33144299
                       双盲安慰剂对照，胆碱能抗炎通路

消化
    IBS-C              Am J Gastroenterol 2024    PMID 39689011
                       便秘型肠易激综合征，自主神经参与

机制
    taVNS/fMRI         Brain Stimul 2018          PMID 29361441
                       同步成像，NTS/LC 激活的直接证据
                       （Feelings 机制文档引用的源头）
```

---

## 二、证据强度与安全性（Meta 层面）

```
安全性（Sci Rep 2022, PMID 36543841）
    系统性综述 + Meta
    → 无严重不良事件
    → 这是对"风险"问题的最有力背书

有效性（Meta）
    失眠     Neuromodulation 2025  PMID 40323248
             显著改善 PSQI/ISI
    抑郁     J Affect Disord 2023  PMID 37230264
             反应率高于假刺激，但证据等级 low-very low
    慢性疼痛 Pain Rep 2024         PMID 39131814
             有效，但偏头痛天数无差异
    癫痫     Seizure 2024          PMID 38820674
             9 研究 788 患者
    抗炎     Neuromodulation 2025  PMID 38795094
             VNS 抗炎通路
    瞳孔指标 Brain Stimul 2025     PMID 39884386
             连续 vs 脉冲协议的客观测量
```

---

## 三、对 Feelings 的三点意义

```
① 技术成熟不用质疑
   2020 前每年个位数，2020 后爆发
   2024=50、2025=89、2026=70
   → "技术成熟、监管保守"有了数据支撑

② 效果有边界，"证明有效"必须自己做
   Meta 明说 low to very low evidence
   → 技术成熟 ≠ 产品有效
   → Feelings 的产品级验证是自己要补的那块
   → 也是 ToB 的筹码（机构买的是被验证的有效）

③ 客观生理标志物是空档
   瞳孔、HRV、fMRI 类客观测量研究少
   → Feelings 的持续在线测量是主场
   → 单次实验 vs 持续监测，别人没做的部分
```

---

## 四、引用立场——开源可审计

```
临床数据全部以 PMID 透明引用
   → 每一条证据都可回溯、可核对、可复现
   → 不藏着、不转述、不夸大
   → 和 Feelings 工程一样：每一步可审计，完全透明

直接引用别人的研究成果
   → 这正是开源的底气：
     引用透明 + 项目开源 = 证据链可被任何人验证
   → 引用不是拿来当挡箭牌
   → 是把"技术成熟"和"产品有效"都交给事实说话
```

---

## 五、和已有文档的咬合

```
bioelectric-intervention-boundaries.md      红线体系（参数锁死、漏桶、不应期）
neural-stimulation-indirect-effects.md      间接效应（靶是神经，作用是整张网）
nerve-endings-and-device-placement.md       Arnold 靶点与设备位置
hardware-development-path.md                监管属性（tVNS 是二类 08 医疗器械）
physiology.md（Interests）                  自主神经、稳态、不应期
```

---

*taVNS 的临床证据已经堆积到数百项，技术成熟度不用再被质疑。但证据的边界同样清晰：安全性强、有效性真实但证据等级偏低。"技术成熟"只证明原理站得住，"你的产品有效"必须自己做。所有引用以 PMID 透明呈现，Feelings 开源，证据链可被任何人验证。引用不是挡箭牌，是把"技术成熟"和"产品有效"都交给事实说话。*
