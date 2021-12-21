local cmd = vim.cmd
local ncmd = vim.api.nvim_command

ncmd('filetype plugin indent on')

cmd([[ autocmd BufNewFile,BufRead *.proto setfiletype proto ]])
cmd([[ autocmd FileType proto setlocal shiftwidth=2 expandtab ]])

cmd([[ autocmd FileType json setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab ]])
cmd([[ autocmd FileType go setlocal tabstop=8 shiftwidth=8 softtabstop=8 textwidth=120 noexpandtab ]])

cmd([[ autocmd BufEnter *.gotmpl set ft=gotmpl]])

cmd([[autocmd FileType markdown setlocal cole=0]])

cmd([[autocmd FileType tmux setlocal foldmethod=marker]])
