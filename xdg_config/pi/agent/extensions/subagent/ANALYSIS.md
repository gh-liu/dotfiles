# Pi Subagent 扩展 6K+ 代码分析

- 日期：2026-09-03
- 数据口径：**7877 行**（含测试与 eval） vs **3300 行**纯生产源码
  - 生产源码 13 文件 3300 行；测试 15 文件 2538 行；eval 7 文件 1937 行；spec.md 88 行；tsconfig.json 14 行（合计 7877 行）
- 范围：`extensions/subagent/`（未覆盖 spec.md、eval/README.md）

## 1. 规模表（文件 / 行数 / 职责）

### 1.1 生产源码（13 文件，3300 行）

| 文件 | 行数 | 职责 |
| --- | ---: | --- |
| `sdk-executor.ts` | 674 | SDK 会话执行器：创建/重启会话、信号与中断、子输出归一化（含凭据脱敏）、tool 进度收集 |
| `index.ts` | 582 | 扩展入口与工具注册：`run/followup/get/cancel/close`、runtime hub、UI 装配、通知 |
| `runtime.ts` | 582 | 运行时状态机：operation 生命周期、progress/onUpdate 转发、后台通知、关闭清理 |
| `live-ui.ts` | 365 | 实时 UI 控制器（进度行、活动工具计数、决策提示） |
| `agents.ts` | 313 | Agent 发现/覆盖（frontmatter、settings 合并）、目录格式化、模型解析 |
| `output.ts` | 153 | 边界化（boundText）、脱敏（redactSecrets）、结构化 handoff（modelSubagentHandoff / serializeSubagentResult） |
| `protocol.ts` | 142 | 公共类型、运行选项、常量、错误类、stripModel 等纯协议定义 |
| `context.ts` | 122 | 工作单创建、根目录/子 cwd 校验、项目指引加载 |
| `render/` | 367 | 渲染层（shared 91、completion 97、result 133、call 42、index 4） |

### 1.2 测试（15 文件，2538 行）

| 文件 | 行数 | 职责 |
| --- | ---: | --- |
| `sdk-executor.test.ts` | 649 | SDK 执行器行为（创建/取消/中断/进度） |
| `agents.test.ts` | 417 | Agent 发现/覆盖 |
| `live-ui.test.ts` | 247 | 实时 UI 渲染与状态 |
| `render/index.test.ts` | 212 | 渲染层集成 |
| `test/harness.ts` | 228 | 测试环境装配（含 `setup()` 共享工具） |
| `test/task-api.test.ts` | 167 | 工具 API 行为 |
| `test/notifications.test.ts` | 165 | 后台通知 |
| `test/discovery.test.ts` | 115 | 扩展发现/注册 |
| `test/rendering-integration.test.ts` | 75 | 渲染与运行集成 |
| `context.test.ts` | 85 | 工作单/cwd 校验 |
| `output.test.ts` | 70 | 边界化/脱敏/序列化 |
| `test/shutdown-cleanup.test.ts` | 51 | 关闭与清理 |
| `test/capacity.test.ts` | 27 | 并发容量 |
| `test/lifecycle.test.ts` | 18 | 生命周期 |
| `test/cancellation.test.ts` | 12 | 取消路径 |

### 1.3 eval（7 文件，1937 行）

| 文件 | 行数 | 职责 |
| --- | ---: | --- |
| `eval/run.mjs` | 614 | 评测运行器（基线/报告/config hash/阈值） |
| `eval/analyze.mjs` | 374 | 行为判定分析 |
| `eval/analyze.test.ts` | 279 | 分析逻辑单测 |
| `eval/fixture.mjs` | 200 | 隔离 fixture 仓库构造 |
| `eval/ui-gallery.mjs` | 163 | UI 渲染样例 |
| `eval/scenarios.mjs` | 146 | 场景定义 |
| `eval/README.md` | 161 | 评测说明（非脚本） |

## 2. 模块依赖图（文字）

```
render/  → protocol.ts, render/shared.ts（内部共享）
protocol.ts（纯类型/常量，无本地依赖 — 依赖图最底层）
output.ts → protocol.ts
agents.ts → protocol.ts
context.ts → protocol.ts, output.ts
live-ui.ts → protocol.ts
runtime.ts → protocol.ts, output.ts, live-ui.ts(type), render/index.ts(type)
sdk-executor.ts → protocol.ts, output.ts（运行时动态 import @earendil-works/pi-coding-agent）
index.ts → agents.ts, context.ts, live-ui.ts, output.ts, runtime.ts,
           sdk-executor.ts, protocol.ts, render/index.ts（顶层装配，唯一注册点）

测试侧：*.test.ts / test/*.ts → 被测模块 + test/harness.ts
eval 侧：eval/*.mjs 独立于 TS 模块图，经 pi CLI 驱动真实扩展（build 临时 agent 目录）
```

依赖方向单向收敛：`protocol.ts` 为公共底座，`output.ts` 为第二层公共能力，`index.ts` 为唯一装配入口；`sdk-executor.ts` 与 `runtime.ts` 之间没有直接依赖（经 index 连接）。

## 3. Top 问题（文件:行号）

1. **创建期取消泄漏 session** — `sdk-executor.ts:236-238`
   `config.createSession` 分支先创建 session（236-237），之后才检查 `initial.signal?.aborted`（238）并 throw；取消发生在 session 创建之后时，已创建的 SDK session（真实路径下 `SessionManager` 进程/`subagent-sessions` 目录）无 dispose 兜底，进程/目录泄漏。
2. **脱敏只进 SDK，未覆盖 UI/通知/get** — `index.ts:157-165`、`sdk-executor.ts:42`
   精确凭据值（`credentialEnvNames` → `redactSecrets(text, secrets)`）只在 sdk-executor 的子输出归一化生效；UI（`live-ui.ts:73-88` 原样展示 activity）、后台通知（`index.ts:170-191` notifySettled）、`get`/`publicSession`（`index.ts:280-307`）只走 `boundText` 的正则模式脱敏（`exactSecretValues` 为空），不覆盖精确值。
3. **无界信任 controller progress** — `runtime.ts:382-414`
   `onProgress` 仅对 summary/decision.question 做 `boundText`；`progress.timeline`/`phase`/`tools` 逐字段 `{ ...entry }` 原样展开（399/400/404/405），`onUpdate` details 亦原样透传（430-432），嵌套数组/字段长度与结构均不设防。
4. **sdk-executor 大量 any 协议漂移** — `sdk-executor.ts` 共 31 处 `: any | as any | <any>`（`modelRuntime?: any` 15、`createSession?: any` 16、`(ModelRuntime as any).create` 253、`(SessionManager as any).create` 283、`(createAgentSession as any)` 285、`listener(event: any)` 464 等）；SDK 外围类型无从校验，改动易漂移。
5. **output serializer 测试与生产路径不一致** — `output.test.ts` vs `index.ts:269`
   `serializeSubagentResult`（`output.ts:127`）在测试中被直接覆盖，但 grep 全仓无任何生产调用者；生产只走 `modelSubagentHandoff` + `boundText`。测试覆盖的 16K 收敛路径不会在生产运行。
6. **config hash 遗漏核心文件** — `eval/run.mjs:423-437`
   `configHash()` 只哈希 `agents/*.md` + 4 个相对路径（`index.ts`、`scenarios.mjs`、`analyze.mjs`、`fixture.mjs`）；`runtime.ts`、`sdk-executor.ts`、`output.ts`、`protocol.ts`、`agents.ts`、`context.ts`、`live-ui.ts`、`render/*` 变更不会使 baseline 失效。
7. **tsconfig 排除测试，失去类型门禁** — `tsconfig.json`
   `"exclude": ["**/*.test.ts"]` 使 `tsc -p subagent/tsconfig.json`（`extensions/package.json` 的 `typecheck:subagent`）不检查测试；vitest 经 esbuild 转译也无类型检查，测试内的协议漂移/any 不受门禁。

## 4. 重构建议

### P0（正确性优先，先于行数目标）

- **P0-1** 修复 `sdk-executor.ts:236-238`：createSession 成功后若 signal 已 aborted，先 dispose 再 throw；整个创建流程置于 try/finally 兜底，杜绝 session/进程/目录泄漏。
- **P0-2** `runtime.ts:382-414`：把 timeline/phase/tools 收敛为公共 bounding 工具（逐条限长、限条目数、限嵌套层），`onUpdate` details 一律走该工具，不再原样透传 controller payload。
- **P0-3** 精确凭据脱敏下沉为公共出口：`live.progress`、`notifySettled`、`publicSession` 统一经携带 credentialValues 的 boundText，覆盖 UI/通知/get。
- **P0-4** `eval/run.mjs` configHash 改为哈希 `subagent/**/*.ts` 全量（或至少全部 13 个生产文件），保证核心文件变更使 baseline 失效。

### P1

- **P1-1** SDK 协议收敛：为 SDK 交互定义最小类型面（SessionLike/EventLike/ToolLike），将 31 处 any 收敛为显式类型与窄化；动态 import 处用类型断言代替 any。
- **P1-2** tsconfig 增补测试类型门禁：新增 `typecheck:subagent-test`（`tsc --noEmit` 纳入 `**/*.test.ts`），或调整 exclude 使 vitest 与 tsc 共用同一 strict 配置。
- **P1-3** 统一序列化路径：生产 handoff 改走 `serializeSubagentResult`，或删除未用序列化器并让 `output.test.ts` 对准 `modelSubagentHandoff`+`boundText` 的真实路径。
- **P1-4** 补齐回归测试：创建期取消（createSession 中 abort）、超大 progress payload、精确凭据在 UI/通知/get 出口的脱敏断言。

### P2

- **P2-1** 收敛 `output.ts` 与 `render/shared.ts` 中重复的 boundedLines/oneLine/boundText 逻辑到共享模块。
- **P2-2** protocol.ts 为公共类型补充契约注释，作为 SDK 类型面收敛的依据。
- **P2-3** eval fixture 版本化并与 configHash 联动，避免 fixture 变更被忽略。

### 行数目标

- 不下沉公共库：生产代码收敛至 **2800-3000 行**（any 收敛、bound 逻辑合并、重复序列化路径删减）。
- 下沉通用能力（bound/redact/session 生命周期抽到扩展共享层后）：**2400-2800 行**。
- 行数是结果不是目标：P0 修复与回归测试先行，行数靠去重达成。

## 5. 验证方法

从 `xdg_config/pi/agent/extensions` 执行（依赖在该目录 `package.json`：vitest 4.1.10、typescript 5.9.2）：

```bash
# 单测（含 subagent 全部 vitest 用例 + 相关类型检查）
npx vitest run subagent

# 类型检查（现状只查生产：tsconfig exclude 测试；P1-2 后应含测试）
npx tsc -p subagent/tsconfig.json

# 完整入口（typecheck:subagent + typecheck:auth + typecheck:status + vitest run）
npm test

# eval 离线自检（无凭证/网络，检查 plan 与 fixture）
node subagent/eval/run.mjs --dry-run

# eval 完整运行（需凭证/网络/真实模型，非 npm test 一部分，见 eval/README.md）
node subagent/eval/run.mjs
node subagent/eval/run.mjs --quick
```

验收对应：

- P0-1：`test/cancellation.test.ts`、`sdk-executor.test.ts` 新增创建期取消用例，`npx vitest run subagent` 通过。
- P0-2/P0-3：`runtime.test`/`live-ui.test`/`notifications.test` 增加超大 payload 与精确凭据断言。
- P0-4：`node subagent/eval/run.mjs --dry-run` 下修改任一生产 TS 文件后 configHash 变化。
- P1-1/P1-2：`npx tsc -p subagent/tsconfig.json`（含测试）零 any 漂移告警通过。

## 6. Dead Code 复核（2026-09-03）

对生产源码 13 文件逐一核对引用（grep 全仓含测试/eval），确认以下结论。本次仅沉淀结论，不动源码。

### P0 真死代码（5 项，生产与测试均无引用，可安全删除）

| 位置 | 符号 | 依据 |
| --- | --- | --- |
| `protocol.ts:23` | `SubagentThinkingSegment` | 全仓仅定义处一处，无任何消费者 |
| `protocol.ts:114` | `SubagentExecutor` | 类型别名仅定义处一处，SDK executor 返回值内联书写未引用该别名 |
| `runtime.ts:119` | `RuntimeHubDeps.idFactory` | hub 内部从不读取该字段；`index.ts:222` 传入后即死（`index.ts:169/541-542` 用的是 options 层 idFactory，与 hub 依赖无关） |
| `runtime.ts:75/93/162` | `operationSnapshot`→`runtimeSnapshot`→`RuntimeHubDeps.snapshot` 死链 | `runtime.ts:565` 的 `snapshot` 实现全仓零调用点，整条链无消费者 |
| `render/shared.ts:74` | `collapseHome` | 仅定义（74）与导出（100）两处，无任何 import；内部亦未使用（`sdk-executor.ts:47` 为各自独立同名本地函数，互不相关） |

### P1 需确认（4 项，仅测试/兼容面引用，删除前需确认意图）

| 位置 | 符号 | 依据 |
| --- | --- | --- |
| `output.ts:127` | `serializeSubagentResult` | 生产 0 引用，仅 `output.test.ts` 3 处直接用；生产走 `modelSubagentHandoff`+`boundText`（对应问题 5） |
| `sdk-executor.ts:640` | `createSdkSubagentExecutor` | 生产 0 引用，仅 `sdk-executor.test.ts` 9 处（import + 8 调用）；内部 `createSdkSubagentController` 才是生产路径 |
| `protocol.ts:131` | `SubagentController.submit?` | 可选成员，接口备忘注释“兼容缝”，全仓无实现方/调用方 |
| `index.ts:98` | `validateAuthEnvAllowlist` | `@deprecated` 别名（指 `validateCredentialRedactionEnvNames`），生产 0 引用，仅 `test/harness.ts` 与 `test/discovery.test.ts` 用 |

### 去 export 即可组（逻辑非死，仅导出无人消费）

- `runtime.ts`：`RuntimeState` / `OperationState`（外部 0 引用，仅模块内部使用）
- `output.ts`：`ModelSubagentHandoff` 等（模块内部闭环，外部 0 引用）
- `agents.ts`：`THINKING_LEVELS`（仅 agents.ts 内部 3 处使用，外部 0 引用）

去 export 不影响逻辑，仅收窄公共面；行数不因此下降。

### 验证基线（复核当日）

- `npx tsc --noEmit`：exit 0（生产 13 文件严格类型检查通过）
- `npx vitest run subagent`：15 文件 140 用例全部通过
- `node subagent/eval/run.mjs --dry-run`：exit 0（离线自检通过）

### 删除顺序与回归范围

1. **P0** 真死 5 项直接删；随后 `npx tsc --noEmit` + 全量 vitest 回归。
2. **P1** 逐项确认意图后删：`serializeSubagentResult` 删后 `output.test.ts` 对准 `modelSubagentHandoff`；`createSdkSubagentExecutor` 删后 `sdk-executor.test.ts` 改走 controller 生产路径；`validateAuthEnvAllowlist` 删后测试改用新名；`submit?` 随相关接口清理。
3. **P2** 去 export 组收窄公共面，无行为变化。
4. 回归用例覆盖：`render/index.test.ts`（渲染层集成）、`task-api`（工具 API）、`notifications`（后台通知）、`local-discovery`/`background-recovery` 场景（发现、恢复路径）。

### 删除状态更新（2026-09-04，已执行）

- **P0 真死 5 项已全部删除**：`protocol.ts` 的 `SubagentThinkingSegment`、`SubagentExecutor`；`runtime.ts` 的 `RuntimeHubDeps.idFactory`（含 `index.ts` 传入点）、`operationSnapshot`→`runtimeSnapshot`→`RuntimeHub.snapshot` 整链；`render/shared.ts` 的 `collapseHome`（函数定义 + export 行，`sdk-executor.ts` 的同名本地函数不受影响）。
- **去 export 组已收窄**：`runtime.ts` 的 `RuntimeState`/`OperationState`、`output.ts` 的 `ModelSubagentHandoff`、`agents.ts` 的 `THINKING_LEVELS` 去掉 `export`，同文件内部继续使用。`SUBAGENT_HANDOFF_MAX_CHARACTERS` 仍被 `sdk-executor.ts` 引用，保持导出。
- **P1 已删 2 项**：`output.ts` 的 `serializeSubagentResult`（`output.test.ts` 改测 `modelSubagentHandoff`+`boundText` 真实入口）；`sdk-executor.ts` 的 `createSdkSubagentExecutor`（`sdk-executor.test.ts` 8 处调用改走 `createSdkSubagentController` 生产路径）。
- **P1 保留 2 项**：`SubagentController.submit?`（有实现与调用，非死代码）、`validateAuthEnvAllowlist`（deprecated 别名，测试仍在用）。
- 本节上文表格为删除前复核快照，符号位置行号以删除前为准，后人阅读以此条更新为准。