# neovim config

Requires Nvim `v0.12.0`

## 7 habits of effective text editing

> https://www.moolenaar.net/habits.html

> https://www.moolenaar.net/habits_2007.pdf

> https://www.youtube.com/watch?v=p6K4iIMlouI

1. 发现效率低的地方: 找到浪费时间的点
2. 寻找更高效率的方法：在线帮助文档、搜索引擎
3. 将第2中寻找到的方法变成习惯：不断提高

-------

1. 快速移动(Moving around quickly): hls *
2. 不要重复(Don't type it twice): comp
3. 错误时就修复它(Fix it when it's wrong): spell abbr
4. 文件很少单独出现(A file seldom comes alone): grep+qf
5. Let's work together
6. 文本是有结构的(Text is structured): pattern
7. 快速更新(Sharpen the saw):

## How I Use NVim

### vimscript or lua

总方针：**默认用 Lua**；遇到"更像命令语言的纯声明片段"，允许保留 Vimscript（或 `vim.cmd[[...]]`）。

- **有逻辑/分支/循环**：用 Lua
- **要回调/闭包**（LSP attach 等）：用 Lua
- **要复用/抽象/拆模块**：用 Lua
- **纯声明、短且稳定**（`:set`/`:hi`/简单 `:autocmd`）：用 Vimscript/`vim.cmd`
- **插件文档只给 Vimscript/只认 `g:` 变量**：优先 Vimscript（先跑通再 Lua 化）
- **追求最短可读**且无需复用：用 Vimscript

### How I Use Fold

**默认配置（Opt-in）：**
- 默认禁用（`foldenable = false`），全部展开（`foldlevelstart = 99`）
- 显示折叠列（`foldcolumn = "1"`）

**折叠方法自动选择：**
1. Treesitter（优先）— 若语言支持 `folds` 查询则自动启用（Lua、Python、Rust等）
2. LSP（备选）— 服务器支持 `textDocument_foldingRange` 时启用
3. Syntax（特殊场景）— Fugitive等特殊buffer用syntax方法
   - Fugitive的commit信息默认全折（`foldlevel = 0`）

**快捷键：** ~ 表示有一定客制化调整
- `zN` ~ 智能折叠深度：`zN` 开启所有，`3zN` 展开到第2层（大于2的foldlevel全关闭）
- `z?` ~ 查看当前折叠配置
- `zi` — 切换是否启用折叠
- `zr` — 添加 count1 到 foldlevel
- `zm` ~ 减去 count1 到 foldlevel；若 foldenable 关闭，先执行 `zR` 打开所有折叠（会设置foldlevel）再执行 `zm`

**使用哲学：**
折叠是工具而非默认。自动启用Treesitter/LSP的精确折叠，但默认禁用保持清爽，需要时手动启用。
