# vimdoc 模板（`doc/<plugin>.txt`）

来源：`:h help-writing`（建议按其格式写；这里给一份可复制的最小模板）。

```text
*myplugin.txt*	MyPlugin short description

==============================================================================
MyPlugin                                                        *myplugin*

INTRODUCTION                                                    *myplugin-intro*
MyPlugin does X.

SETUP                                                           *myplugin-setup*
Recommended minimal config (example): >
  lua require('myplugin').setup({})
<

COMMANDS                                                        *myplugin-commands*
:MyPluginDoThing                     Do the thing.

MAPPINGS                                                        *myplugin-mappings*
The plugin exposes <Plug> mappings; users should map them:
>
  lua vim.keymap.set('n', '<leader>x', '<Plug>(MyPluginDoThing)')
<

TROUBLESHOOTING                                                 *myplugin-troubleshooting*
- Run `:checkhealth myplugin` for diagnostics.

==============================================================================
vim:tw=78:ts=8:noet:ft=help:norl:
```

## 写作要点（摘自 `help-writing`）

- 第一行格式推荐：`*plugin_name.txt*` +（Tab）+ 简短描述
- help tag 用 `*tag*` 定义；引用用 `|tag|`
- 代码块用 `>` 开始、`<` 结束；也可以 `>lua`/`>vim` 指定语言
- 底部 modeline 只设置局部选项（不要设置全局选项）

