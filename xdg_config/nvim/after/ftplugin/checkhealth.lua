vim.wo.foldmethod = "expr"
vim.wo.foldexpr = "(getline(v:lnum-1)=~'^======='?'>1':1)"
