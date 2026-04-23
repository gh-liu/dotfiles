# neovim config

Requires Nvim `v0.13.0`

## 7 habits of effective text editing

1. 快速移动(Moving around quickly): hlsearch可视化搜索、hjkl、mark、%...
2. 不要重复(Don't type it twice): 补全、abbr缩写、宏、dot重复命令...
3. 错误时就修复它(Fix it when it's wrong): spell拼写检查、abbr纠正拼写错误...
4. 文件很少单独出现(A file seldom comes alone): grep跨文件搜索 + qf调整修改
5. 协同工作(Let's work together): 善用`!cmd`或`%!filter`、管道等与外部工具配置
6. 文本是有结构的(Text is structured): 正则pattern、`matchit`、`treesitter`...
7. 快速更新(Sharpen the saw): 定义审视工作流，优化重复操作

核心思想：发现低效 → 找到更好的方式 → 养成习惯，循环迭代

1. 发现效率低的地方: 找到浪费时间的点
2. 寻找更高效率的方法：在线帮助文档、搜索引擎
3. 将第2中寻找到的方法变成习惯：不断提高

### links

1. https://www.moolenaar.net/habits.html
2. https://www.moolenaar.net/habits_2007.pdf
3. https://www.youtube.com/watch?v=p6K4iIMlouI

## How I Use NVim

- **Command > Map**: 优先用命令而非映射（可发现、可脚本化、可组合）
- **Trust > Prompt**: 信任用户而非防御性提问（Vim只在不可逆时提示）
- **Minimal Intervention > Maximum Power**: 工具克制，用户掌控

本质：显式优于隐式，可发现优于隐藏。

## vimscript or lua

总方针：
- **默认用 Lua**
- 遇到"更像`命令`语言的`纯声明`片段"，允许保留 Vimscript（或 `vim.cmd[[...]]`）

具体：
- 有逻辑/分支/循环：用 Lua
- 要回调/闭包（LSP attach 等）：用 Lua
- 要复用/抽象/拆模块：用 Lua
- 使用的插件文档只给 `Vimscript`/只认 `g:` 变量：优先 `Vimscript`（先跑通再 Lua 化）
- 纯声明、短且稳定、无需复用（`:set`/`:hi`/简单 `:autocmd`）：用 `Vimscript`/`vim.cmd`

## How I Use Fold

> 使用哲学：折叠是工具而非默认。自动设置Treesitter/LSP的精确折叠方法，但默认禁用保持清爽，需要时手动启用。

**默认配置**
- 默认禁用（`foldenable = false`），全部展开（`foldlevelstart = 99`）
- 显示折叠列（`foldcolumn = "1"`）

**折叠方法自动设置**
1. Treesitter（优先）— 若语言支持 `folds` 查询则自动启用（Lua、Python、Rust等）
2. LSP（备选）— 服务器支持 `textDocument_foldingRange` 时启用（额外设置foldtext为vim.lsp.foldtext）
3. Syntax（特殊场景）— Fugitive等特殊buffer用syntax方法
   - Fugitive的commit信息默认全折（`foldlevel = 0`）

**快捷键**： ~ 表示有一定客制化调整
- `zn` - 关闭折叠(foldenable=false)
- `zN` ~ 恢复折叠(foldenable=true)，支持指定折叠深度：`zN` 开启所有，`3zN` 展开到第2层（大于2的foldlevel全关闭），不带数字则恢复之前的样子
- `zi` — 切换是否启用折叠
- `z?` ~ 查看当前折叠配置
- `zr` — 添加 count1 到 foldlevel
- `zm` ~ 减去 count1 到 foldlevel；若 foldenable 关闭，先执行 `zR` 打开所有折叠（会设置foldlevel到当前最大层级）再执行 `zm`
- `zC` ~ 递归关闭光标处所有折叠；支持指定目标层级：`zC`/`1zC` 关到顶层，`2zC` 关到第2层，`3zC` 关到第3层

## How I Use Diff

> mini.diff 对比 working vs index，`[c` `]c` 移动，`gh` 推到 index，`gH` 以 index 为准（即丢弃）；不用 overlay 
> `:h diff-mode` 内建的 diff 能力: diffthis,diffoff; diffget,diffput; diffsplit, diffupdate, diffpatch 
> vim-fugitive 使用 vim diff 的能力，比较git任意Blob对象（即文件）

diffe.vim 日常工作流
refuge.vim git review

TODO: diffopt, diffanchors(Mark,Pattern,Visual,line)

### 高亮

- `DiffAdd` `DiffChange` `DiffDelete` `DiffText` 用 `bg`，表示整块 diff 区域或行内变更块
- `Added` `Removed` `Changed` 用 `fg`，表示增删改语义色，适合 signs、treesitter、文本标签等不该整块铺底色的场景
- mini.diff Gutter ( MiniDiffSignAdd MiniDiffSignChange MiniDiffSignDelete )
- treesitter ( @diff.plus @diff.minus @diff.delta )
