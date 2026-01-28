---
name: nvim-lua-plugin
description: Neovim Lua 插件开发最佳实践。涵盖 plugin/lua 加载结构、lazy-loading、命令/autocmd/映射、配置拆分、vimdoc、health checks 和 mini.test 测试。
scope: repo-only
---

# Nvim Lua Plugin

## When to Use This Skill

使用此技能当用户需要：
- 创建新的 Neovim Lua 插件
- 设计或重构 plugin/ 和 lua/ 目录结构
- 实现命令、autocmd、`<Plug>` 映射或 Lua API
- 添加 vimdoc 文档或 health checks
- 为现有插件编写自动化测试
- 优化插件启动性能（lazy-loading）

## Overview

这个 skill 帮助你以"贴近 Neovim 官方最佳实践"的方式开发 Lua 插件：在不牺牲启动性能的前提下，提供清晰的对外接口（命令/`<Plug>`/Lua API）、可维护的目录结构、可诊断的健康检查、可阅读的 vimdoc，以及使用 `mini.test` 的自动化测试。

## 快速开始（最小结构 + 最小入口）

最小目录结构：

```
plugin/<name>.lua
lua/<name>/init.lua
lua/<name>/config.lua
doc/<name>.txt
```

最小入口（`plugin/<name>.lua`）：

```
vim.api.nvim_create_user_command("<Name>Do", function(opts)
  require("<name>").do_action(opts)
end, { nargs = "*" })
```

最小实现（`lua/<name>/init.lua`）：

```
local M = {}

function M.do_action(opts)
  -- ... 实际逻辑
end

return M
```

## 关键决策（先推理，再写代码）

1. **识别需求类型**（决定入口与加载时机）
   - 需要用户显式调用的功能（命令/映射）？
   - 需要跟随事件触发（autocmd）？
   - 只对特定 filetype 生效？
   - 是否有插件自有 UI buffer/窗口？
   - 启动性能是否敏感？（通常敏感）

2. **先查权威来源**（避免网上文章过时）
   - 插件开发：`:h lua-plugin`
   - Lua 使用：`:h lua-guide`
   - API：`:h api`
   - 自检：`:h health-dev`
   - vimdoc：`:h help-writing`、`:h :helptags`

3. **选择目录与加载模型**（默认推荐）
   - `plugin/<name>.lua`：只注册入口（commands/keymaps/autocmd），保持极小。
   - `lua/<name>/...`：放实现模块；在入口回调里 `require()` 实现模块（隐式 lazy-loading）。
   - filetype 相关：用 `ftplugin/<ft>.lua` 或 autocmd（参考 `:h lua-plugin-filetype`）。

4. **选择对外接口形态**（减少冲突/提升可组合性）
   - 默认优先：`<Plug>` 映射 + 用户自定义 `vim.keymap.set()`（`:h lua-plugin-keymaps`）。
   - 其次：用户命令 `nvim_create_user_command()`。
   - 最灵活：导出 `require('<name>').action(opts)` 形式的 Lua API（适合参数组合很多）。

5. **决定配置与初始化的拆分**
   - 推荐：`setup(opts)` 只 merge 默认配置；初始化逻辑放在 `plugin/`/`ftplugin/`。
   - 例外：需要显式 opt-in 或初始化高度可定制时，才考虑合并到 `setup()`（`:h lua-plugin-init`）。

## 实施步骤（详细步骤与检查点）

### Step 0：收集最小上下文（避免盲写）

至少确认这些信息（写在注释/设计草稿里即可）：
- 插件名（决定 `lua/<name>/`、help tags 前缀、`:checkhealth <name>`）
- 入口：命令名/`<Plug>` 名称/autocmd 事件/文件类型
- 配置项与默认值（必须项/可选项）
- 外部依赖（其它插件/系统命令/可选依赖）
- 性能约束（启动期是否允许 I/O/扫描？通常不允许）

### Step 1：设计目录结构与入口（默认模板）

推荐结构（来自 `:h lua-plugin` / `:h lua-guide`）：

```
plugin/<name>.lua            启动时执行：只注册 commands/keymaps/autocmd
lua/<name>/init.lua          模块入口：导出公共 API
lua/<name>/config.lua        默认配置 + setup(opts)
lua/<name>/actions.lua       具体功能实现
lua/<name>/health.lua        :checkhealth 支持（可选但推荐）
doc/<name>.txt               vimdoc
```

关键点：`plugin/<name>.lua` 顶层避免 `require('<name>...')` 重模块；把 `require()` 移到回调里（`:h lua-plugin-defer-require`）。

### Step 2：实现入口（命令 / `<Plug>` / autocmd）

#### 命令

用 `vim.api.nvim_create_user_command()`（`:h nvim_create_user_command()`）。回调内部再 `require()` 实现模块：
- 好：命令回调里 `local m = require('<name>')`
- 避免：`plugin/<name>.lua` 顶层 `local m = require('<name>')`

#### `<Plug>` 映射

遵循 `:h lua-plugin-keymaps`：插件作者提供 `<Plug>(...)`，用户用 `vim.keymap.set()` 绑定到自己喜欢的按键。

#### autocmd

用 `vim.api.nvim_create_autocmd()`（`:h nvim_create_autocmd()`）。对于 filetype 特化，也可以用 `ftplugin/<ft>.lua`。

### Step 3：配置与校验（既稳又不打扰用户）

- `setup(opts)` 只覆盖默认配置，避免做昂贵动作（I/O、扫描、创建大量 autocmd/keymap）。
- 轻量校验用 `vim.validate()`（`:h vim.validate()`）。
- “未知字段/拼写错误”这类深度校验可放到 health check，减少运行期开销（`:h health-dev`）。

对比示例（不推荐 vs 推荐）：

```
-- 不推荐：setup 里注册大量 autocmd/keymap
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  vim.api.nvim_create_autocmd("BufEnter", { callback = M.on_buf_enter })
end

-- 推荐：setup 只合并配置，注册放在 plugin/ 或 ftplugin/
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
end
```

### Step 4：可观测性与错误处理

- 用 `vim.notify()`/`vim.notify_once()` 给用户明确且可操作的提示（`:h vim.notify()`）。
- 对可选依赖用 `pcall(require, ...)` 兜底；错误信息应包含“如何修复”。
- 开发/排障时：
  - 用 `:messages` 查看启动期输出
  - 用 `:restart` 快速观察改动效果（参考 `:h lua-plugin-troubleshooting`）
  - 用 `nvim --startuptime <file>` 量化插件启动影响（参考 `:h --startuptime`）

### Step 5：Health checks（推荐）

为插件提供 `lua/<name>/health.lua`（或 `lua/<name>/health/init.lua`），返回带 `check()` 的表（`:h health-dev`）。

检查范围建议：
- 配置是否有效（类型/范围/未知字段）
- 外部依赖是否存在
- 初始化是否正确（例如避免重复初始化）

### Step 6：vimdoc（强烈建议）

提供 `doc/<name>.txt` 并遵循 `:h help-writing`：
- 首行 `*<name>.txt*` + 简述
- tags 用 `*tag*`，交叉引用用 `|tag|`
- 代码块用 `>`/`<`（也可 `>lua`/`>vim`）

提醒用户运行 `:helptags` 为 doc 生成 tags（`:h :helptags`）。

### Step 7：版本与弃用

遵循 `:h lua-plugin-versioning`：
- 用 SemVer 表达破坏性变更
- 弃用用 `vim.deprecate()`（`:h vim.deprecate()`）或 `---@deprecate` 注解提前告知

### Step 8：测试（推荐 mini.test）

为插件添加自动化测试可以大幅提升可维护性。推荐使用 `mini.test`（见 `references/testing-mini-test.md`）：

**为什么选 mini.test**：
- 与 Neovim 深度集成，支持 child Neovim 进程隔离测试
- 支持 test set、hooks、参数化与过滤
- 内置 screenshot/reference 测试，适合 UI 插件

**推荐目录结构**：
```
tests/
  test_smoke.lua      -- 冒烟测试
  test_commands.lua   -- 命令/API 测试
scripts/
  minimal_init.lua    -- 测试用最小配置（加载 mini.test + 你的插件）
  minitest.lua        -- 可选：项目特定测试脚本
```

**核心工作流**（详见 `references/testing-mini-test.md`）：
1. 每个 test 文件返回一个 test set（`MiniTest.new_set()`）
2. 用 `MiniTest.new_child_neovim()` 启动隔离的 child 进程
3. 在 child 里加载插件、执行操作、用 `MiniTest.expect.*` 断言
4. 本地 `:lua MiniTest.run()` 或 CI `nvim --headless ...`

**最小运行示例**（与 `scripts/minimal_init.lua` 配合）：

```
nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run()" -c "qa"
```

**常用断言**见 `:h MiniTest.expect`。

## 规约（30%：必须/禁止/建议）

### MUST

- `plugin/<name>.lua` 只做注册入口（commands/keymaps/autocmd），保持极小（`:h lua-plugin-lazy`）。
- 在 `plugin/<name>.lua` 避免顶层加载重模块；把 `require()` 放进回调（`:h lua-plugin-defer-require`）。
- 若插件有外部依赖或复杂配置，提供 `health.lua` 以支持 `:checkhealth`（`:h health-dev`）。
- 如果发布给用户使用，提供 vimdoc（`:h lua-plugin-doc`、`:h help-writing`）。

### AVOID

- 自动创建大量全局 keymap（容易冲突）；优先 `<Plug>`/命令/Lua API（`:h lua-plugin-keymaps`）。
- 启动期做 I/O/扫描/遍历项目文件等昂贵动作；把成本推迟到用户触发时（`:h lua-plugin-lazy`）。
- 在 `setup()` 里混入大量初始化逻辑，导致用户必须显式调用才能“默认可用”（除非确实要 opt-in）（`:h lua-plugin-init`）。

### SHOULD

- 用 `vim.validate()` 做轻量参数校验；昂贵校验放到 health check（`:h vim.validate()`、`:h health-dev`）。
- 关键错误用 `vim.notify()` 给出可操作的修复建议（`:h vim.notify()`）。
- 采用 LuaLS 注解（LuaCATS/EmmyLua）提高类型安全（`:h lua-plugin-type-safety`）。
- 为核心功能写自动化测试（推荐 `mini.test`，见 Step 8）。

## 资源索引（按需阅读/复制）

### references/

- `references/nvim-lua-plugin-guidelines.md`：快速索引
- `references/api_reference.md`：完整指南（按 help tags 组织）
- `references/nvim-lua-api-cheatsheet.md`：按任务组织的 API 速查
- `references/common-patterns.md`：常见代码模式与最佳实践（可直接复制）
- `references/vimdoc-template.md`：vimdoc 最小模板
- `references/testing-mini-test.md`：mini.test 测试框架速用指南

### assets/

- `assets/plugin-skeleton/`：可复制的插件骨架（目录树 + 文件模板）
- `assets/minimal-repro-config/`：最小复现用的 `init.lua` 模板（可配合 `nvim --clean -u <file>`）
- `assets/mini-test-skeleton/`：mini.test 测试骨架（`tests/` + `scripts/minimal_init.lua`）

## 故障排查（常见问题）

### 插件加载失败
```vim
" 查看启动期错误消息
:messages

" 用最小配置复现
nvim --clean -u minimal_init.lua

" 查看启动时间分析
nvim --startuptime startup.log
```

### 命令或映射不工作
```vim
" 检查命令是否存在
:command MyPluginCommand

" 检查映射定义
:map <Plug>(MyPluginAction)

" 查看 plugin/ 文件是否加载
:scriptnames
```

### Health check 失败
```vim
" 运行 health check
:checkhealth myplugin

" 调试 health.lua
:lua vim.notify(vim.inspect(require('myplugin.health').check()))
```

### 测试失败
```vim
" 运行所有测试
:lua MiniTest.run()

" 运行特定文件
:lua MiniTest.run_file('tests/test_smoke.lua')

" 运行特定测试
:lua MiniTest.run('test_name')

" headless 模式（CI）
nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run()" -c "qa"
```

## 示例场景

### 场景 1：创建新插件骨架
```bash
# 复制骨架
cp -r assets/plugin-skeleton/* your_plugin/

# 重命名文件和模块
# plugin/myplugin.lua → plugin/yourplugin.lua
# lua/myplugin/* → lua/yourplugin/*
```

### 场景 2：为现有插件添加测试
```bash
# 复制测试骨架
cp -r assets/mini-test-skeleton/* your_plugin/

# 修改 scripts/minimal_init.lua 添加你的插件路径
```

### 场景 3：修复启动性能问题
1. 用 `nvim --startuptime` 分析热点
2. 检查 `plugin/*.lua` 是否有顶层 `require()`
3. 将重模块加载移到回调内
4. 参考 `:h lua-plugin-lazy`
