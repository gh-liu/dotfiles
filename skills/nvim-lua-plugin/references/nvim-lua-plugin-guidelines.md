# Neovim Lua 插件开发要点（索引）

如果你只想快速回忆“作者最佳实践”，优先看本文件；需要细节时再打开同目录下的 `api_reference.md`（它已经被替换成更完整的指南，按 help tags 组织）。

## 一句话原则

- **入口轻、实现懒**：`plugin/<name>.lua` 只注册入口；实现放 `lua/<name>/...` 并在回调里 `require()`（`:h lua-plugin-lazy`、`:h lua-plugin-defer-require`）。
- **少做默认 keymap**：优先 `<Plug>`/用户命令/Lua API（`:h lua-plugin-keymaps`）。
- **配置与初始化分离**：`setup(opts)` 只 merge 配置；初始化放 `plugin/`/`ftplugin/`（`:h lua-plugin-init`）。
- **可诊断**：提供 `health.lua`，支持 `:checkhealth <name>`（`:h health-dev`）。
- **可阅读**：提供 vimdoc（`:h help-writing`）并生成 helptags（`:h :helptags`）。
- **对未来友好**：SemVer + `vim.deprecate()`（`:h lua-plugin-versioning`、`:h vim.deprecate()`）。

## 推荐阅读顺序（遇到争议先回这里）

1. `:h lua-plugin`
2. `:h lua-guide`
3. `:h api`
4. `:h health-dev`
5. `:h help-writing`

## 相关文件

- 详细指南：`api_reference.md`
- API 速查：`nvim-lua-api-cheatsheet.md`
- vimdoc 模板：`vimdoc-template.md`

