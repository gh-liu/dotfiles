---
name: technical-writing
description: Use when drafting or revising technical prose that readers will use to make a decision, follow a procedure, or take over work. Examples include design notes, runbooks, incident reports, and handoffs. Also use when someone explicitly asks to improve wording, clarity, or structure, even for a single sentence.
---

# 技术写作

动笔前先确定谁会读这段文字、读者已经知道什么，以及读完后要做什么。把读者最需要的判断或动作写在开头，只补充理解它所需的背景。改写已有文字时，保留原意、技术细节和确定程度。

## 按读者的任务组织内容

- **做决定**。先写需要决定什么以及建议选哪项，再给出影响选择的约束、依据和取舍。指出哪些待验证的条件会改变建议。
- **执行操作**。先交代适用条件，把实际风险放在对应操作之前。按执行顺序写步骤，保留可复制的命令。说明如何判断成功，以及失败后从哪里查起。
- **接手工作**。先写当前状态和影响范围，再交代已完成的工作、验证结果与待办。有阻塞时写明解除阻塞需要什么。

## 审稿时检查

- 用具体的主体和动词写清谁做了什么。一句话表达一个主要意思。较长内容用读者关心的问题分段，同类信息使用一致的结构。
- 同一概念始终使用同一术语。保留标识符、API 名称、命令和引文的准确形式。在读者可能不熟悉的缩写首次出现时解释含义。
- 对照证据检查每项结论，保留影响判断的前提、范围、单位和例外。分别写清已经观察到什么、据此推断什么，以及建议做什么。

例如，排障记录可以写成「日志显示这次响应命中了缓存。缓存未失效可能解释旧数据。可绕过缓存重试同一请求，对比两次响应。」验证报告可以写成「超时重试的回归测试已通过。生产环境中的重试行为仍待验证。」

清晰表达的原则参考了 ASD-STE100，并按中文工程协作场景调整。[ASD Simplified Technical English](https://www.asd-ste100.org/)
