# Subagent Extension Refactoring Plan (2026-08-25) — DONE

> 设计优先、小步可回滚。每个阶段独立提交，任一门禁失败即回滚该阶段。
> **状态：P1–P3 全部完成**（P1 `8a955248`、P2 `f9ca6f52`；全量 vitest 264/264 绿）。

## 背景（证据）

- `render.ts`: 472 行 / 圈复杂度 **240（全项目最高）**。三类渲染职责（call / result / completion）+ ~25 个私有 helper 混在一个文件。
- `index.test.ts`: 1,647 行，单个 describe 块约 1,400 行，导航困难。
- 安全网：typecheck + vitest 全绿基线，测试：源码 ≈ 1.2:1。
- spec §6.3 明确 runtime/sdk-executor 的 cohesion 是有意设计 —— 核心状态机**不在**重构范围。

## 目标

1. `render.ts` 按渲染对象拆分，复杂度分摊、编辑局部性提升；外部导入路径零变化。
2. `index.test.ts` 按契约域拆分为多个测试文件，共享 fixture 抽出；断言逐字节不变（move-only）。
3. spec.md §6.3 / §12 实现映射同步更新。

## 非目标（约束）

- 不动 `runtime.ts` / `sdk-executor.ts` 控制器与状态机。
- 不改工具表面、协议、持久化布局、live-ui。
- 不重构 eval 工具链；不引入新抽象层或运行时服务。

## 目标结构（flat 布局，与现有目录风格一致）

```
render.ts            # barrel: export * from "./render-*.ts"（保留全部既有导入路径）
render-shared.ts     # 跨消费者复用的纯格式化 helper
render-completion.ts # SUBAGENT_COMPLETION_MESSAGE + 类型 + renderSubagentCompletion
render-call.ts       # renderSubagentCall
render-result.ts     # renderSubagentResult
```

Helper 归属规则：≥2 个消费模块 → `render-shared.ts`；单一消费者 → 与其同文件。
依赖方向：call / result / completion → shared；无环。

测试拆分（P2）：按契约域移动测试组到新 `*.test.ts` 文件，共享 setup 抽为 helper；
**move-only**——断言与字符串零编辑，仅移动代码与补 import。

## 阶段与门禁

| 阶段 | 内容 | 门禁 | 提交 |
| --- | --- | --- | --- |
| P1 | render 拆分 | `npm run typecheck:subagent` 绿 + `vitest run` 全绿；render.test.ts 断言零改动 | `8a955248` |
| P2 | index.test.ts 拆分 | 测试总数与 P1 后基线一致（264）且全绿 | `f9ca6f52` |
| P3 | spec 同步（§6.3/§12/§13 + 头部修订记录）+ 本文件收尾 | 内容核对 | 本次提交 |

## 回滚策略

每阶段一个 commit；失败 `git revert` 该阶段即可，阶段间无交叉依赖（P2 不依赖 P1 的产物）。

## 已知风险

- vitest 对 `.ts` 直接导入的解析：沿用现有 `./xxx.ts` 后缀风格即可，无需改 tsconfig/vitest 配置。
- index.test.ts 共享临时目录 fixture：拆分时必须保持每个文件独立的 setup/teardown 语义，不得共享可变状态。

---

# Iteration 2（2026-08-25 下午）：目录化 + 上色 + spec 压缩

## 目标结构

```
subagent/
  render/
    index.ts            # barrel（原 render.ts）；导入方改为 "./render/index.ts"
    shared.ts / completion.ts / call.ts / result.ts   # 原 render-*
    index.test.ts       # 原 render.test.ts（渲染器单测，与实现同目录）
  test/
    harness.ts          # 原 index-test-utils.ts（集成测试公共设施）
    capacity|discovery|lifecycle|notifications|rendering-integration|
    shutdown-cleanup|steering-interrupt .test.ts     # 原 index-*（去前缀）
```

SRP 归属依据：走完整注册链路的扩展级测试归入 `test/`；纯单元测试继续贴源码（agents/context/output/sdk-executor/render 各自的 .test.ts）。**tsconfig `include` 必须从 `["*.ts"]` 改为 `"**/*.ts"`**（exclude 保持排除 *.test.ts）。

## Call 标题着色（功能，非 move-only）

仅 `run/start` 分支的身份标签：name=`toolTitle`+bold（不变）、model=`accent`、thinking=按级别映射 `thinking<Cap>`（如 high→`thinkingHigh`），未知级别回退 `thinkingText`；分隔符 `·` 用 `dim`。测试：新增一个记录型 fake theme 断言三段使用不同色键。

## Spec 压缩

保留全部标题编号与所有标识符/数值/路径字面量；§1–4 收紧叙述、§5–12 合并段落为要点、§13 保表删文、§14 历史一笔带过、§16 已决事项各压至 1–2 行；目标 ≤600 行（原 ~1290）。文件引用一律写最终布局名。

## 门禁与提交

A 结构 → B 上色 → C 文档，各自独立 commit；A/B 后跑全量 vitest（264 保持），C 仅内容核对。

- Iteration 2 status: A structure commit 7c82cf0e done; B coloring commit c2b0a370 done; C spec compression done.
