# Neovim Lua API Cheatsheet（面向插件作者）

这是一份“按任务组织”的速查表；遇到疑问时仍以 `:h` 内置文档为准。

## 注册入口（建议放在 `plugin/<name>.lua`，并尽量延迟 require）

- **用户命令**：`:h nvim_create_user_command()`
  - `vim.api.nvim_create_user_command(name, command, opts)`
- **自动命令**：`:h nvim_create_autocmd()`
  - `vim.api.nvim_create_autocmd(event, opts)`
  - 常见：`FileType`、`BufEnter`、`TextYankPost`、`LspAttach`
- **键位映射**：`:h vim.keymap.set()`
  - `vim.keymap.set(modes, lhs, rhs, opts)`
  - 推荐导出 `<Plug>(...)`，让用户自己映射（`:h lua-plugin-keymaps`）

## 模块与懒加载

- **加载模块**：`:h lua-guide-modules`
  - `require('myplugin')` 会缓存模块
  - 需要重新加载：`package.loaded['myplugin'] = nil`
- **建议模式**：入口只注册，回调里 `require()`（`:h lua-plugin-defer-require`）

## 参数与配置校验

- **轻量校验**：`:h vim.validate()`
  - `vim.validate(name, value, validator[, optional][, message])`
  - validator 常用：`'string'|'number'|'table'|'boolean'` 或自定义函数
- **深度/昂贵校验**：建议放到 health check（`:h health-dev`）

## 通知与日志（用户可见）

- **通知**：`:h vim.notify()`
  - `vim.notify(msg, level?, opts?)`
  - `vim.notify_once(...)`（`:h vim.notify_once()`）避免刷屏

## Buffer/Window 相关（常用入口）

- **当前 buffer / window**：
  - `vim.api.nvim_get_current_buf()`
  - `vim.api.nvim_get_current_win()`
- **读写 buffer 内容**：
  - `vim.api.nvim_buf_get_lines(bufnr, start, end_, strict_indexing)`
  - `vim.api.nvim_buf_set_lines(bufnr, start, end_, strict_indexing, replacement)`

## Health checks（自检）

- **约定**：`:h health-dev`
  - 放到 `lua/<name>/health.lua` 或 `lua/<name>/health/init.lua`
  - 返回 `M = { check = function() ... end }`
- **输出**：`:h vim.health`
  - `vim.health.start(name)`
  - `vim.health.ok(msg)` / `vim.health.warn(msg, advice?)` / `vim.health.error(msg, advice?)` / `vim.health.info(msg)`

## vimdoc（让用户能 `:h <name>`）

- **写作规范**：`:h help-writing`
- **生成 tags**：`:h :helptags`

## 弃用与兼容

- **弃用提示**：`:h vim.deprecate()`
  - `vim.deprecate(name, alternative, version, plugin?, backtrace?)`

