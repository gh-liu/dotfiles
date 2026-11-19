---
name: engineering-workflow
description: Use when an engineering task needs investigation to define success, trace behavior across components, or choose between implementations with material trade-offs. Also use when compatibility or state changes require explicit invariants and verification. Apply the relevant steps as the investigation unfolds.
---

# 工程工作流

从当前影响决定的问题入手。调查使目标或影响范围发生变化时，回到对应步骤更新判断。按需使用以下方法。

## 理解问题

- 用一个可观察的结果描述成功。明确本次要解决的问题、范围之外的需求、约束，以及变更前后必须成立的条件。
- 从正常入口沿调用方、实现和配置追踪行为，对照契约、测试或日志。跨组件问题可按需画出控制流或数据流，找出在哪个边界能独立观察和测试行为。
- 有多个可能成因时，选择能区分它们的最小实验。必要时检查部署环境或外部依赖。标明推断及依据。调查后仍有会改变方案或结果的需求歧义时，向 LIU 确认。

## 选择方案

- 比较可行方案如何满足同一组验收条件。遵循项目既有模式，默认依次考虑正确性与安全、可维护性、性能。
- 选择满足约束的最小改动。引入抽象或拆分文件时，说明它简化了哪段逻辑、满足了什么复用需求，或隔离了什么独立职责。
- 长期决策的依据若难以从代码、测试或现有文档还原，在项目已有文档体系中记录取舍。

## 实现与验证

- 将变更拆成可独立验证的小步。修复缺陷时优先用回归测试稳定复现原问题，再验证修复。适合时采用红、绿、重构循环。用测试固化长期行为，用代码表达长期约束。
- 从用户实际使用的入口核对验收条件，再检查调查中识别出的不变量。例如，修改持久化格式时，既验证新数据的写入，也验证已有数据的读取。
- 按影响范围和风险选择验证深度。关键验证受阻时，写明原因、证据能覆盖的范围，以及仍存在的风险。

## 交付

先回答用户最初的问题，再简述改动和验证结果。只补充影响审阅、使用或下一步决定的取舍和限制。
