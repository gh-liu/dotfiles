augroup term_setup
  autocmd!
  autocmd TermOpen * startinsert
  autocmd TermOpen * noremap <buffer> dq <cmd>bd!<cr>
augroup END

nnoremap `\ <cmd> vsplit <bar> term <cr>
nnoremap `- <cmd> bo split  <bar> term <cr>

tnoremap jk <C-\><C-n>
tnoremap <esc> <C-\><C-n>
"tnoremap <C-g> <C-\><C-n>
"tnoremap <C-w> <C-\><C-n><C-w>
tnoremap <C-p> <Up>
tnoremap <C-n> <Down>
tnoremap <C-f> <Right>
tnoremap <C-b> <Left>
tnoremap <C-a> <Home>
tnoremap <C-e> <End>
tnoremap <C-q> <C-\><C-n>:quit<cr>
