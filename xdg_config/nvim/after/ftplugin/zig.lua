vim.wo.foldmethod = "expr"
vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"

-- disable automatic code formating
vim.g.zig_fmt_autosave = 0
