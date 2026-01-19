# Neovim Lua 插件作者指南（基于内置帮助文档）

本文件沉淀"规约之外的细节"：当你需要写/改 Neovim Lua 插件时，优先遵循这里的最佳实践，并在不确定时回到 Neovim 的内置帮助文档（这通常比网上文章更贴近你当前 Neovim 版本）。

## 权威来源（建议优先阅读的 help tags）

- `:h lua-plugin`（插件开发指南）
  - `:h lua-plugin-lazy`
  - `:h lua-plugin-defer-require`
  - `:h lua-plugin-keymaps`
  - `:h lua-plugin-init`
  - `:h lua-plugin-doc`
  - `:h lua-plugin-versioning`
- `:h lua-guide`（Lua 使用生存手册）
  - `:h lua-guide-api`
  - `:h lua-guide-modules`
- `:h api`（Nvim API）
  - `:h nvim_create_autocmd()`
  - `:h nvim_create_user_command()`
- `:h health-dev` / `:h vim.health`（自检）
- `:h help-writing` / `:h :helptags`（vimdoc 文档）

## 目录与加载模型（最容易踩坑的地方）

### `plugin/` vs `lua/`

- `plugin/<name>.lua` 会在启动时被 eager 执行（详见 `:h lua-plugin-lazy`）。它应当**只做"入口注册"**：commands/keymaps/autocmds 等。
- `lua/<name>/...` 里的模块应当按需 `require()`（详见 `:h lua-guide-modules`）。
- `require()` 会缓存模块：第二次 `require()` 不会再次执行；如需热重载，需清理 `package.loaded[...]`（见 `:h lua-guide-modules`）。

### 延迟 `require()`（隐式 lazy loading）

参考 `:h lua-plugin-defer-require`：在 `plugin/<name>.lua` 顶层 `require('foo')` 会把成本提前到启动期。更好的做法是把 `require()` 放进 command/keymap 的回调中，让用户"第一次使用功能"时再加载实现模块。

## 对外接口策略（减少冲突与降低用户心智负担）

### Keymaps：优先 `<Plug>` 或命令

参考 `:h lua-plugin-keymaps`：不要自动创建大量全局 mapping（容易冲突）。更稳妥的导出方式是：

- 提供 `<Plug>(YourPluginAction)` 映射，让用户在 `init.lua` 用 `vim.keymap.set()` 自行绑定。
- 或提供 `:YourCommand`（用户命令）。
- 或导出 Lua API（`require('yourplugin').action(opts)`），适合参数组合很多的场景。

### 命令、自动命令与校验

- 用户命令：`vim.api.nvim_create_user_command()`（`:h nvim_create_user_command()`）。
- 自动命令：`vim.api.nvim_create_autocmd()`（`:h nvim_create_autocmd()`）。
- 参数校验：`vim.validate()`（`:h vim.validate()`）。对于"未知字段"这类昂贵校验，可放到 health check 中做（见下文）。

## 初始化与配置（拆分"配置"与"初始化"）

参考 `:h lua-plugin-init`：推荐"严格分离的配置 + 智能初始化"。常见模式：

- `setup(opts)` 只负责把 `opts` merge 到默认配置（不做 I/O、不创建复杂对象、不注册大量钩子）。
- 初始化逻辑放在 `plugin/` 或 `ftplugin/`，保证开箱即用。

只有在以下场景才考虑把初始化也放进 `setup()`：

- 需要用户显式 opt-in（默认不应启用功能）。
- 初始化高度可定制，且误配置风险高。

## 自检（health checks）

参考 `:h health-dev`：为插件提供 `lua/<name>/health.lua`（或 `lua/<name>/health/init.lua`），返回带 `check()` 的表。`:checkhealth <name>` 会自动发现并执行它。

推荐检查项：

- 配置字段/类型是否正确（对昂贵校验尤其合适）
- 外部依赖是否存在
- 是否正确初始化（例如只初始化一次）

常用 API：`vim.health.start/ok/warn/error/info`（`:h vim.health`）。

注意：health 是"诊断/建议"，不要在其中改用户环境。

## vimdoc 文档（让用户能 `:h yourplugin`）

参考 `:h lua-plugin-doc` 与 `:h help-writing`：

- 在 `doc/yourplugin.txt` 写 vimdoc。
- 第一行建议 `*yourplugin.txt*` + 简述（`help-writing`）。
- 用 `*tag*` 定义 help tag，用 `|tag|` 交叉引用。
- 让用户或 CI 运行 `:helptags` 为 `doc/` 生成 tags（`:h :helptags`）。

如果你用 Markdown 写文档，可以用 `panvimdoc` 转 vimdoc（`lua-plugin-doc` 提到）。

## 类型安全（可选，但推荐）

参考 `:h lua-plugin-type-safety`：使用 LuaCATS/EmmyLua 注解 + LuaLS（lua-language-server）做静态检查；对稍大一点的插件尤其划算，可在 CI 里提前抓住类型错误。

## 版本与弃用（对用户友好）

参考 `:h lua-plugin-versioning`：

- 用 SemVer（`https://semver.org/`）表达破坏性变更。
- 需要弃用时，优先用 `vim.deprecate()`（`:h vim.deprecate()`）或 `---@deprecate` 注解提前告知。
