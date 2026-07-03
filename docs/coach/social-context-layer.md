# 社交上下文感知层——四维之上的 Social Context Layer

> 作者：qc
> 日期：2026-07-03
> 性质：设计稿——PBM 之上新增的社交风格感知层
> 核心：当前四维 PBM 告诉教练"身体在怎么反应。"缺了最关键的一帧——"在谁面前。"同一个人——在朋友面前直白到脏话连篇——在老板面前迂回到每一个句号都换成了波浪线。四维数值可能一模一样——教练需要用完全不同的语气去接。不是加第五维——是在四维之上焊一层 context-aware 的社交风格感知。

---

## 零、为什么四维不够

同一个用户。同一组 Emotional 数值。在朋友面前 = 直接锤。在老板面前 = 暗着说。四维只记录了"身体有情绪。"没有记录"身体在这个等控器之前的等控器等控器等控器等控器——是和哪个等控器坐等控器在一起的。"

---

## 二、数据结构——不是贴标签，是分 context

不是给用户贴一个"直白型"或"迂回型"的脸谱。是分场景建模。

```
enum SocialContext { Friend, Work, Romantic, Family, Stranger }

enum SocialStyle { Direct, Indirect, Neutral }

struct SocialStyleProfile {
    default_style: SocialStyle,
    contexts: HashMap<SocialContext, SocialStyle>,
    context_confidence: HashMap<SocialContext, f64>,
}
```

---

## 三、提取方式——从对话数据自动推断

- 用词直白度：祈使句占比、脏话占比
- 冲突处理速度：从 disagreements 到 resolve 的延迟
- 沉默时长：对话中的平均 pause
- 场景标记：从对话内容提取 context 关键词——"老板说要""我妈打电话""周末出去玩"

---

## 四、教练对话双通道

直白型 = 直接给数据。"你昨晚那次 session——Emotional 掉了。"迂回型 = 走引导。"最近说不上来——但好像有点什么——你感觉到了吗。"同一个结论——两套入口——取决于对面是朋友还是老板。

---

## 五、咬合现有系统

```
Core-FORGET P1#7         新增条目
baseline-break-tracking  迂回型在高压期的异常沉默/异常输出——需要被单独追踪
life-history-log         社交场景切换的时间轴——哪些关系改变了对话风格
session/anchor.rs        PersonalityAnchor 需要风格维度 per context
```

---

*四维是"身体在怎么反应。"Social Context Layer 是"在谁面前。"不是加第五维——是给每一维加上"对面坐着谁"这一帧。同一个人——换了一个 context——换了一套语言——教练必须能读到这一帧。*