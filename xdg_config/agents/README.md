# Agent 配置：分层、落点与工作流

本文档记录个人 Agent 配置的分层架构、资源选型准则与日常协作工作流。

## 1. 四层资源模型

Agent 的能力与行为按**触发方式**、**职责边界**和**上下文成本**分为四层：

| 层级   | 资源                                         | 本质              | 解决什么问题                                             | 触发方式           | 上下文成本                                         |
|:-------|:---------------------------------------------|:------------------|:---------------------------------------------------------|:-------------------|:---------------------------------------------------|
| **L0** | 常驻规范（`AGENTS.md` / `APPEND_SYSTEM.md`） | 全局协议          | **底线与默认协作方式**（语言、红线、证据标准）           | 每轮自动注入       | 高（全文常驻）                                     |
| **L1** | 能力层（Tools / Extensions / MCP）           | 执行原语          | **能干什么**（有严格 schema，连接外部世界与隔离环境）    | 模型按需调用       | 中（直接声明的工具常驻 schema；延迟加载的工具更低） |
| **L2** | 方法层（Skills）                             | 可复用 SOP / 策略 | **怎么做**（分析框架、判断标准、CLI 工具使用手册）       | 模型按语义按需加载 | 低（`description` 常驻，正文按需加载）             |
| **L3** | 入口层（Prompts）                            | 任务模板          | **现在做什么**（参数化高频任务、声明读写护栏与输出结构） | 用户显式触发       | 触发前为零（调用时展开）                           |

## 2. 选型决策规则

新增一条规则、能力或流程时，按以下顺序判断落点：

1. **是否每轮对话都必须遵守？**
   - 是 → 放 **L0**（`AGENTS.md` 放跨工具共识；`APPEND_SYSTEM.md` 放单一 harness 特有约定）。
   - 保持极简，不在 L0 堆砌具体场景的 SOP。
2. **现有工具（尤其是 `bash` / `read` / `edit`）能否完成底层动作？**
   - 不能（需要强类型约束、权限隔离、UI 渲染、外部服务接入或独立子会话）→ 新增 **L1**（Tool / Extension / MCP）。
   - 能 → 不造细粒度新 Tool，进入第 3 步，用文档约束通用工具的用法。
3. **这是可复用的方法论/领域手册，还是用户一键发起的具体动作？**
   - 可跨任务复用的方法、判断标准，或模型容易用错参数、漏掉步骤的 CLI 手册 → **L2（Skill）**，编写规范见 [skills/README.md](skills/README.md)。
   - 高频、需要明确输入与读写边界的任务入口 → **L3（Prompt）**。

### 关键边界

- **Prompt 不重复 Skill**：Prompt 只声明“本次目标、输入参数、读写护栏（如只读/只改测试）和输出重点”，不硬编码长篇方法论；方法论留在 Skill 中复用。
- **自建 Skill 互斥可路由**：每个自建 Skill 的 `description` 明确触发条件和相邻边界，避免重叠与误路由。外部 Skill 的 `description` 不受控，与之冲突时在自建 Skill 的 `description` 中划清边界。

## 3. 目录结构与单一真源（SSOT）

配置按**跨 Harness 可移植性**拆分：

```text
xdg_config/
├── agents/                        # 跨 Harness 单一真源（受 git 管理）
│   ├── README.md                  # 本文档
│   ├── AGENTS.md                  # L0 通用协作协议
│   └── skills/                    # L2 自建通用工程方法论
│       ├── README.md              # Skill 编写与路由规范
│       └── <skill-name>/SKILL.md
├── amp/
│   └── AGENTS.md -> <dotfiles>/xdg_config/agents/AGENTS.md
├── bin/skillsu                    # Skills 安装/同步脚本
└── pi/agent/                      # Harness 专属层（以 pi 为例）
    ├── AGENTS.md -> <dotfiles>/xdg_config/agents/AGENTS.md
    ├── APPEND_SYSTEM.md           # L0 pi 专属补充（codemode、classifier）
    ├── settings.json              # 引用 ../../agents/skills
    ├── keybindings.json           # pi 快捷键
    ├── mcp.json                   # L1 MCP 服务配置
    ├── extensions/                # L1 pi 扩展工具（mpl-render、subagent 等）
    └── prompts/                   # L3 任务入口模板

~/.agents/skills/                  # L2 外部安装或本地项目链接的工具型 Skills
                                   # （如 agent-browser、typesafe-ai、worktrunk、devops-cli）
```

`AGENTS.md` 的 symlink 使用绝对路径（`<dotfiles>` 即本仓库根目录），仓库位置变化后需重建。

### 归口原则

- **`xdg_config/agents/`**：工具无关的个人资产（协作协议、自建方法论 Skills）。
- **`~/.agents/skills/`**：第三方或特定业务项目提供的工具手册型 Skills，与个人通用方法论分离。
- **`xdg_config/<harness>/`**：依赖特定运行时的配置、扩展、MCP 与快捷键。
  - `prompts/` 的任务语义工具无关，但语法依赖 pi：frontmatter 的 `argument-hint` 与正文的 `${@:-...}` 参数展开是 pi 模板语法，`score.md` 还依赖 harness 提供 decision 模型（pi 中为通过 codemode 调用的 classifier）。迁移到其他 harness 时需改写这些部分，因此暂留在 `xdg_config/pi/agent/prompts/`。

### 安装与同步

Skills 通过 [`skillsu`](../bin/skillsu) 安装，用法为 `skillsu [agent]`（默认 `pi`）：

- **pi**：自建 Skills 由 `settings.json` 直接引用 `../../agents/skills`，不复制；脚本另将 `~/.pi/agent/skills` 链接到 `$PI_CODING_AGENT_DIR/skills`。
- **其他 harness**（如 amp）：脚本用 `skills add` 将 `xdg_config/agents/skills` 安装到该 harness 的全局 skills 目录。修改自建 Skill 后需重新运行 `skillsu <agent>` 同步。
- **第三方 Skills**：所有 harness 都由脚本通过 `skills add -g` 安装（当前为 agent-browser、typesafe-ai、worktrunk）；`devops-cli` 是指向业务项目的手动 symlink。

## 4. 工程工作流（Skills × Prompts）

自建 Skills（L2）独立于具体入口，按 `理解 → 决策 → 实现 → 验证 → 交付` 覆盖完整工程策略：

- **理解**：`problem-modeling`（界定模糊问题）、`read-code`（理解代码与 diff）、`root-cause-analysis`（定位异常根因）
- **决策**：`design-options`（推导硬约束与权衡方案）、`architecture-decision-records`（查阅、撰写或替代 ADR）
- **实现**：`write-code`（最小改动与代码化约束）
- **验证**：`verify-changes`（真实入口测试与不变量验证）、`ablation-studies`（单因素对照实验）
- **交付**：`visual-explanation`（图表、diff 与界面展示）、`technical-writing`（技术文档写作）、`git-commit`（原子提交与本地历史整理）

Prompts（L3）表达用户显式发起的**动作与读写护栏**，在日常任务中与上述策略按阶段配合：

| 阶段       | Prompt 入口  | 读写护栏                            | 常配合的 Skills                                                                 |
|:-----------|:-------------|:------------------------------------|:--------------------------------------------------------------------------------|
| 状态对齐   | `/restate`   | 只读（仅总结）                      | —（自包含）                                                                     |
| 问题与方案 | `/explore`   | 只读（列约束与选项，不推荐）        | `problem-modeling`、`read-code`、`design-options`、`visual-explanation`         |
| 方案收敛   | `/score`     | 只读（decision 模型量化打分并推荐） | `typesafe-ai`                                                                   |
| 根因定位   | `/debug`     | 只读（最小判别实验）                | `root-cause-analysis`、`read-code`、`ablation-studies`                          |
| 最小实现   | `/implement` | 仅改约定范围                        | `write-code`、`verify-changes`                                                  |
| 补充验证   | `/test`      | 仅改测试与 fixtures                 | `verify-changes`                                                                |
| 变更审阅   | `/review`    | 只读（质疑必要性与回归风险）        | `read-code`、`verify-changes`、`technical-writing`                              |
| 架构记录   | 显式要求记录 | 文档写操作                          | `architecture-decision-records`                                                 |
| 提交变更   | 显式要求提交 | Git 写操作                          | `git-commit`                                                                    |

### 使用习惯

- **先只读、后修改**：问题未定型或根因未证实前，优先用只读入口（`/explore`、`/debug`、`/restate`）收敛共识，再进入 `/implement`。
- **把护栏留在入口**：通过 Prompt 的显式边界（只读 / 只改测试 / 仅改约定范围）防止模型越界，比事后回滚成本更低。
- **定期回收与瘦身**：
  - 在多轮对话里反复口头强调的约束 → 沉淀为 Skill 或 Prompt。
  - 长期不再触发的 Skill 或 Prompt → 及时清理，保持路由清晰。
