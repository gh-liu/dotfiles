local api = vim.api
local create_command = vim.api.nvim_create_user_command

vim.cmd([[
command! -nargs=+ -bang -complete=command R if !<bang>0 | wincmd n | endif
    \ | call execute(printf("put=execute('%s')", substitute(escape(<q-args>, '"'), "'", "''", 'g')))

" execute last command and insert output into current buffer
inoremap <c-r>R <c-o>:<up><home>R! <cr>
]])

-- vim: foldmethod=marker
