vim.cmd([[
setl nonumber
setl norelativenumber
]])

local opts = { buffer = 0 }
vim.keymap.set("t", "kk", [[<C-\><C-n>]], opts)
vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
