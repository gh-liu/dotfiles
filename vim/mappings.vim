" Smart way to move between windows, tabs, buffers, quickfix
nnoremap ]w <c-w>w
nnoremap [w <c-w>W

nnoremap ]t :tabn<cr>
nnoremap [t :tabp<cr>

nnoremap ]b :bnext<cr>
nnoremap [b :bprev<cr>

nnoremap ]q :cnext<cr>
nnoremap [q :cprev<cr>

nnoremap ]l :lnext<cr>
nnoremap [l :lprev<cr>

" close windows, tabs, quickfix-win, localtion-win
" nnoremap <Leader>cw :close<cr>
" nnoremap <Leader>ct :tabclose<cr>

" nnoremap <Leader>cq :ccl<cr>
" nnoremap <Leader>cl :lcl<cr>

" new a window or tab
nnoremap <Leader>nw :new<cr>
nnoremap <Leader>nt :tabnew<cr>

"" window
nnoremap <leader>ws :split<CR>
nnoremap <leader>wv :vsplit<CR>

" <Leader>[1-9] move to tab [1-9]
for s:i in range(1, 9)
  execute 'nnoremap <Leader>' . s:i . ' ' . s:i . 'gt'
endfor

" repeat in opposite direction
noremap \ ,

" Quit
" inoremap <C-Q>     <esc>:q<cr>
" nnoremap <C-Q>     :q<cr>
" vnoremap <C-Q>     <esc>
nnoremap <Leader>q :q<cr>
nnoremap <Leader>Q :qa!<cr>
vnoremap <Leader>q <esc>

" movement in command-edit mode
cnoremap <C-a> <HOME>
cnoremap <C-h> <left>
cnoremap <C-j> <down>
cnoremap <C-k> <up>
cnoremap <C-l> <right>

" Movement in insert mode
imap <C-e> <END>
imap <C-a> <HOME>
inoremap <C-h> <left>
inoremap <C-l> <right>
inoremap <C-j> <down>
inoremap <C-k> <up>
inoremap <C-^> <C-o><C-^> " edit alternate file

" qq to record, Q to replay
nnoremap Q @q

nnoremap Y y$

" Open new line below and above current line
nnoremap <leader>o o<esc>
nnoremap <leader>O O<esc>

" Save
inoremap <C-s>     <C-O>:update<cr>
nnoremap <C-s>     :update<cr>

" Disable CTRL-F on tmux
nnoremap <C-f> <nop>
nnoremap <Leader><C-f> <C-f>

" Tags
nnoremap <C-]> g<C-]>
nnoremap g[ :pop<cr>

" Moving lines
nnoremap <silent> <C-k> :move-2<cr>
nnoremap <silent> <C-j> :move+<cr>
nnoremap <silent> <C-h> <<
nnoremap <silent> <C-l> >>
