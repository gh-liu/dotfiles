# pi agent

## session, tree

| 概念             | 推荐理解                                 |
|------------------|------------------------------------------|
| session          | 一个主线任务的工作空间                   |
| session 的主路径 | 已确认的事实、决策与实现进展             |
| /tree 产生的旁支 | 服务于同一目标的探索、调查、实验、review |
| /fork、/clone    | 继承已有背景，另起一条独立推进的工作线   |

其中 /fork 与 /clone 的区别主要是从哪里继承：

- /fork：回到过去某次提问前，换一种要求重新走。 例如：“之前决定用 Redis，现在改成 PostgreSQL，重新设计。”
- /clone：保留当前已经走到的状态，从这里分出去。 例如：“方案已确定，原会话继续实现；新会话基于这些结论编写迁移方案。”

这段工作是为了回到原目标继续推进，还是要独立推进、独立收尾？

- 要回来 → 优先 /tree。
- 要独立推进 → 优先 /fork 或 /clone。
- 与原任务基本无关，也不需要继承背景 → 直接新 session，避免带入无关上下文。

## prompts

`agent/prompts/*.md` 是可按需触发的阶段性控制点（`prompts/` 下的一级 `.md` 会直接注册为 `/` 命令，因此说明与约束记录在本文件，不在 `prompts/` 下放 README）：

| 阶段       | Prompt       | 职责                                          | 默认目标（省略宾语时）             | 写边界              | 常配合的 Skills                                                         |
|:-----------|:-------------|:----------------------------------------------|:-----------------------------------|:--------------------|:------------------------------------------------------------------------|
| 状态对齐   | `/restate`   | 压缩重述目标、约束/不变量、方案进展与未决问题 | 当前会话推进的任务状态             | 只读（仅总结）      | —（自包含）                                                             |
| 问题与方案 | `/explore`   | 基于代码硬约束发散候选方案并对比核心取舍      | 当前会话讨论的问题或需求           | 只读（不推荐）      | `problem-modeling`、`code-reading`、`design-options`、`visual-explanation` |
| 方案收敛   | `/score`     | 硬约束过滤 + decision 模型加权比选并推荐      | 当前会话提出的候选方案             | 只读（只推荐）      | `typesafe-ai`                                                              |
| 根因定位   | `/diagnose`  | 故障取证、竞争假设鉴别与根因定位              | 当前会话暴露的报错、失败或异常行为 | 只读（不修复）      | `failure-diagnosis`、`code-reading`、`ablation-studies`                    |
| 最小实现   | `/implement` | 按既定范围最小实现并完成针对性验证            | 当前会话敲定的方案、修复或修改项   | 仅改约定范围        | `code-writing`、`change-verification`                                      |
| 测试验证   | `/test`      | 复用已有测试，仅为未覆盖的可观测行为补测并运行 | 当前会话实现的能力或目标行为       | 仅改测试与 fixtures | `change-verification`                                                      |
| 变更审阅   | `/review`    | 审查正确性、变更必要性、更简替代与测试缺口    | 当前会话实现或修改的代码变更       | 只读                | `code-reading`、`change-verification`、`technical-writing`                 |

### 使用习惯

- **先只读、后修改**：问题未定型或根因未证实前，优先用只读入口（`/explore`、`/diagnose`、`/restate`）收敛共识，再进入 `/implement`。
- **把护栏留在入口**：通过 Prompt 的显式边界（只读 / 只改测试 / 仅改约定范围）防止模型越界，比事后回滚成本更低。

### 模板格式

所有模板统一采用轻量标签分节的固定 Markdown 骨架（frontmatter + 目标首句 + `Strategy:` / `Output:` / `Boundary:`）：

```markdown
---
description: <verb-first summary of the action>
argument-hint: "[<optional target>]"
---

<Command> [qualifier]: ${@:-<default target in the current session>}

Strategy:
- <How to execute and core criteria; inline conditional stops that change execution.>

Output:
- <Information priority and required decision elements; degraded output when preconditions fail.>

Boundary: <Unconditional side-effect and authority boundary.>
```

### 编写约束

- **`/动词 [宾语]` 语法与会话默认目标**：命令名统一取单一动词，调用形式为 `/动词 [宾语]`，`argument-hint` 用方括号标注可选宾语（如 `"[changes, git ref, or path]"`）。正文首句通过 `${@:-...}` 将未传参时的默认目标绑定到当前会话对应产物；需要作用到会话外目标（如特定路径或 Git 范围）时由调用方显式传参，不在模板内堆叠多级 Git 回退猜测逻辑。
- **统一四段结构，聚焦单一能力**：每个模板只覆盖单一动作，按上述固定骨架的四个位置各司其职（保持精简，不越界代行相邻阶段职责）：
  1. **任务目标（首句）**：首词即命令名（首字母大写），明确动作并绑定默认目标（`${@:-...}`）。命令名单独作动词时语义须与 `Boundary:` 一致：仅不够精确时在其后加限定短语（如 `Score and compare:`）；与边界冲突时改命令名（如隐含「修复」的 `debug` 改为只读的 `diagnose`）。
  2. **执行策略与约束（`Strategy:`）**：规定如何执行及核心判准，与结果表述分离。前提不满足或触发异常时的**条件退化/停止分支**写在它影响的那一段，避免硬凑结论：改变执行方式的（如方案失效时停止并保留已有改动、已有覆盖时不新增测试）紧贴 `Strategy:` 对应条目；改变交付内容的写在 `Output:`（见下条）。
  3. **执行结果（`Output:`）**：聚焦结果本身与核心决策要素，约束信息优先级而非死板排版格式；前提不满足时的降级输出（如证据不足时报剩余可能与下一步检查、决策模型失败时留空分数且不推荐）也写在这里。
  4. **任务边界（`Boundary:`）**：末尾单行声明无条件红线，同时划清**副作用/写边界**（如 `Read-only`、`Modify only test files and fixtures`）与**决策权/阶段边界**（如不替用户推荐、只总结不新开调查、只推荐不实现）。
- **解耦常驻规则、Skills 与底层 API**：正文内不硬编码其他 `/prompt` 名称（靠会话上下文自然衔接），不重复 `AGENTS.md` 已有的全局纪律（如保护无关未提交改动、引用证据），也不抄入 skill 细则或工具沙箱的内部函数签名，避免双源维护。
- **结论面向人类可读（推理脚手架与输出分离）**：假设鉴别、必要性反问、量化打分等仅作为推理骨架；输出用直白工程语言先给结论再附证据，不暴露内部流程标签或模型协议字段。

## extensions

本仓库维护的 Pi 扩展位于 `agent/extensions/`（每个子目录为独立 npm 包；[Pi extension API documentation](https://pi.dev/docs/latest/extensions)）：

| Extension                                             | Purpose                                                        |
|-------------------------------------------------------|----------------------------------------------------------------|
| [auth](agent/extensions/auth/README.md)               | 启动 Pi 会话时导入 Codex OAuth 凭证。                          |
| [status](agent/extensions/status/README.md)           | 在底部状态栏显示活动状态、模型、token 用量、费用与上下文占比。 |
| [subagent](agent/extensions/subagent/README.md)       | 将有界任务委派给全新隔离的 Pi 会话并返回交接结果。             |
| [sessions](agent/extensions/sessions/README.md)       | 按目录与标题检索已保存的 Pi 会话。                             |
| [mpl-render](agent/extensions/mpl-render/README.md)   | 在 QuickJS 沙箱中运行原生 `mpl` 绘图代码并渲染 PNG 图表。    |

### 编写约束

- **工具 `description` 参考 skill 描述编写（渐进式披露）**：常驻给模型的 `description` 只保留路由所需的三类信息——**做什么**、**何时使用（以及替代什么默认做法）**、**完整文档路径（如本扩展 `README.md` / 类型声明）**。不要把详细 API、样式约定、边界限制堆进常驻描述，而是在描述中提示模型首次调用前按需 `read` 文档。
- **`exposure` 按发现性选择**：
  - 需要模型主动感知并优先选用的工具使用 `exposure: "direct"`（配合简短 `promptSnippet` 进入 `<tools>` 列表），通过精简描述控制常驻 token，而不是靠 `deferred` 隐藏；
  - `exposure: "deferred"` 不会出现在顶层工具列表或 `codemode` 描述中，只有模型主动发起 `tool_search` / `searchTools()` 时才能加载，仅适合低频或在系统提示/工作流中已显式引导检索的工具；
  - 仅用于编排或不应被脚本嵌套调用的工具使用 `exposure: "model-only"`。

### 安装与测试

各扩展目录均为独立 npm 包。使用 Node.js 24 及以上版本，在对应扩展目录（`agent/extensions/<name>/`）执行：

```sh
npm ci
npm test
```

`npm test` 会执行类型检查与 Vitest 单测。各包开发依赖固定在 Pi 1.6.0；运行时由 Pi 宿主提供 `pi-ai`、`pi-coding-agent`、`pi-tui` 与 `typebox` peer dependencies。

在 `agent/extensions/` 下可使用脚本统一升级全部扩展包的 Pi 依赖版本并运行各包测试：

```sh
./update-pi-deps.mjs           # latest version on npm
./update-pi-deps.mjs --from-pi # match local `pi --version`
./update-pi-deps.mjs --dry-run # preview changes only
```
