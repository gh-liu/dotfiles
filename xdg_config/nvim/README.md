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

## vimscript or lua

总方针：**默认用 Lua**；遇到"更像命令语言的纯声明片段"，允许保留 Vimscript（或 `vim.cmd[[...]]`）。

- **有逻辑/分支/循环**：用 Lua
- **要回调/闭包**（LSP attach 等）：用 Lua
- **要复用/抽象/拆模块**：用 Lua
- **纯声明、短且稳定**（`:set`/`:hi`/简单 `:autocmd`）：用 Vimscript/`vim.cmd`
- **插件文档只给 Vimscript/只认 `g:` 变量**：优先 Vimscript（先跑通再 Lua 化）
- **追求最短可读**且无需复用：用 Vimscript
