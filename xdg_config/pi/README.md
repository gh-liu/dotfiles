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

| Prompt       | 职责                                               | 写边界    |
|--------------|----------------------------------------------------|-----------|
| `/explore`   | 调查现状与约束，遇模糊停下澄清，清晰则发散候选方案 | 只读      |
| `/restate`   | 压缩重述当前理解、约束/不变量与未决问题            | 只读      |
| `/score`     | 硬约束过滤 + 决策模型量化打分                      | 只读      |
| `/implement` | 按已确认方案或审查结论最小实现与验证               | 生产+测试 |
| `/review`    | 反事实消融审查，评估必要性与测试覆盖               | 只读      |
| `/test`      | 在合适测试层补强有区分度的测试                     | 仅测试    |

### 编写约束

- **只聚焦自身能力范围**：每个 prompt 只负责单一阶段的职责与硬边界（`Boundaries`），不越界代行其他环节。
- **使用共同语言，不耦合其他 prompts**：各 prompt 共用同一套状态词汇（如 `acceptance criteria`、`non-goals`、`constraints`、`invariants`、`active ADRs`、`verified facts` vs `unverified assumptions`）以自然衔接，但正文内**不要提及或硬编码其他 `/prompt`**，保证每条命令独立可用、可任意组合。

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
