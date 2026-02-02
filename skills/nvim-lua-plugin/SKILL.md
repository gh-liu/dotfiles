---
name: nvim-lua-plugin
description: Neovim Lua 插件开发核心最佳实践。plugin/lua 加载结构、lazy-loading、命令/keymaps/autocmd、配置设计。
scope: repo-only
---

# Nvim Lua Plugin

## When to Use This Skill

使用此技能当用户需要：
- 创建新的 Neovim Lua 插件
- 设计或重构 plugin/ 和 lua/ 目录结构
- 实现命令、autocmd、`<Plug>` 映射或 Lua API
- 优化插件启动性能（lazy-loading）

## Overview

以 Neovim 官方最佳实践为基准，设计轻量启动、清晰接口、易于维护的插件结构。核心原则：**plugin 入口极小，实现延迟加载，配置与初始化分离，优先 `<Plug>` 接口**。

## 快速开始

最小骨架（复制 `assets/plugin-skeleton/` 并改名）：

```
plugin/<name>.lua           -- 只注册入口，保持极小
lua/<name>/init.lua         -- 导出公共 API
lua/<name>/config.lua       -- 默认配置 + setup()
doc/<name>.txt              -- vimdoc（可选但推荐）
```

关键：`plugin/<name>.lua` 顶层不 `require()` 重模块；在命令/autocmd 回调里延迟加载。

## 关键决策

1. **需求类型**：用户显式调用(命令/映射)、还是事件驱动(autocmd)、还是 filetype 特化？性能敏感吗？
2. **权威源**：优先 `:h lua-plugin`、`:h lua-guide`、`:h api`、`:h health-dev`、`:h help-writing`。
3. **加载模型**：plugin/ 只注册，lua/ 放实现，回调里 `require()`（`:h lua-plugin-defer-require`）。
4. **对外接口**：优先 `<Plug>` 映射 > 用户命令 > Lua API（参考 `:h lua-plugin-keymaps`）。
5. **配置拆分**：`setup()` 只 merge 配置，不做初始化；初始化放 plugin/ 或 ftplugin/。

## 实施步骤

**Step 1**：确认插件名、入口点（命令/事件/filetype）、配置项、外部依赖。

**Step 2**：设计目录结构。推荐：
```
plugin/<name>.lua           -- vim.api.nvim_create_user_command() 等，回调内 require()
lua/<name>/init.lua         -- M.action() 等公开函数
lua/<name>/config.lua       -- 默认配置 + M.setup(opts)
lua/<name>/health.lua       -- :checkhealth 支持（可选但推荐）
doc/<name>.txt              -- vimdoc（可选但推荐）
```

**Step 3**：实现 `plugin/<name>.lua` 入口。命令示例：
```lua
vim.api.nvim_create_user_command("MyCommand", function(opts)
  require("myplugin").action(opts)
end, { nargs = "*" })
```

**Step 4**：实现 `lua/<name>/init.lua` 模块和 `lua/<name>/config.lua` 配置。

**Step 5**：(可选) 添加 `health.lua` 和 vimdoc，提升诊断与易用性。

## 规约

### MUST

- `plugin/<name>.lua` 只注册入口（commands/keymaps/autocmd），保持极小。
- 避免在 `plugin/<name>.lua` 顶层 `require()` 重模块；延迟到回调内。
- 复杂插件提供 `health.lua` 支持 `:checkhealth`。
- 发布给用户提供 vimdoc。

### AVOID

- 自动创建全局 keymaps（冲突风险）；优先 `<Plug>` 映射。
- 启动期做 I/O/扫描/遍历；推迟到用户触发。
- `setup()` 混入大量初始化；只 merge 配置。

### SHOULD

- 用 `vim.validate()` 做轻量参数校验（`:h vim.validate()`）。
- 错误用 `vim.notify()` 给出可操作建议（`:h vim.notify()`）。
- 采用 LuaLS 注解（LuaCATS）提高类型安全。
- 为核心逻辑编写测试（推荐 mini.test）。

## Testing with mini.test

### 为什么选 mini.test

- Neovim 官方认可，与 Neovim API 无缝集成
- 支持 child process 隔离（每个测试跑独立的 nvim 实例）
- 内置常见断言，test set / hooks / 参数化支持

### 最小设置

项目根目录创建：

```
tests/
  test_smoke.lua          -- 冒烟测试
scripts/
  minimal_init.lua        -- 测试用最小配置
```

**scripts/minimal_init.lua** 模板：

```lua
-- Load mini.test and your plugin
vim.opt.rtp:prepend(vim.fn.getcwd())

require("mini.test").setup()
require("myplugin")  -- Load your plugin
```

**tests/test_smoke.lua** 模板：

```lua
local MiniTest = require("mini.test")
local expect = MiniTest.expect

local T = MiniTest.new_set({
  execute_after_each = function()
    -- Cleanup after each test
  end,
})

T["basic action works"] = function()
  local result = require("myplugin").action({ arg = "test" })
  expect.equality(result.status, "ok")
end

T["command exists"] = function()
  vim.cmd("MyCommand")
  expect.equality(vim.fn.exists(":MyCommand"), 2)
end

return T
```

### 运行测试

**本地开发**：
```vim
:lua MiniTest.run()              " 运行全部
:lua MiniTest.run_file('tests/test_smoke.lua')  " 运行单文件
```

**CI / 无界面**：
```bash
nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run()" -c "qa"
```

### 常见断言

```lua
expect.equality(actual, expected)         -- a == b
expect.truthy(value)                      -- value is truthy
expect.falsy(value)                       -- value is falsy
expect.no_error(function() ... end)       -- no exception
expect.error(function() ... end)          -- raises exception
expect.match(string, pattern)             -- string matches pattern
```

查阅详细列表：`:h MiniTest.expect`

### 最佳实践

1. **Child process 隔离**：复杂交互用 `MiniTest.new_child_neovim()`（参考 `:h MiniTest.new_child_neovim()`）
2. **覆盖关键路径**：命令执行、参数校验、配置 merge、错误处理
3. **避免顶层副作用**：测试要可重复运行、互不干扰
4. **清晰的 test set 名称**：用 dot notation 分组（如 `T["config.merge"]`）

## 权威文档（优先阅读）

```vim
:h lua-plugin              " 插件开发指南
:h lua-guide               " Lua 使用手册
:h api                     " API 参考
:h health-dev              " Health check 开发
:h help-writing            " Vimdoc 规范
:h lua-plugin-lazy         " Lazy-loading 最佳实践
:h lua-plugin-keymaps      " Keymap 设计
```
