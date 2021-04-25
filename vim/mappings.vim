" use 'w' move between tabs
nnoremap [w :tabprevious<cr>
nnoremap ]w :tabnext<cr>
nnoremap [W :tabfirst<cr>
nnoremap ]W :tablast<cr>

" close windows, tabs, quickfix-win, localtion-win
nnoremap <Leader>cw :close<cr>
nnoremap <Leader>ct :tabclose<cr>
nnoremap <Leader>cW :close!<cr>
nnoremap <Leader>cT :tabclose!<cr>

nnoremap <Leader>cq :ccl<cr>
nnoremap <Leader>cl :lcl<cr>

" new a window or tab
" nnoremap <Leader>nw :new<cr>
nnoremap <Leader>nt :tabnew<cr>

"" window
" nnoremap <leader>ws :split<CR>
" nnoremap <leader>wv :vsplit<CR>

" <Leader>[1-9] move to tab [1-9]
" for s:i in range(1, 9)
"   execute 'nnoremap <Leader>' . s:i . ' ' . s:i . 'gt'
" endfor

" repeat in opposite direction
noremap \ ,

" Quit
inoremap <C-Q>     <esc>:q<cr>
nnoremap <C-Q>     :q<cr>
vnoremap <C-Q>     <esc>
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
" nnoremap <C-]> g<C-]>
" nnoremap g[ :pop<cr>

" Moving lines
" nnoremap <silent> <C-k> :move-2<cr>
" nnoremap <silent> <C-j> :move+<cr>
" nnoremap <silent> <C-h> <<
" nnoremap <silent> <C-l> >>

"use <ctrl>+j/k/h/l to switch the right direction just like you use the j/k/h/l to move the cursor
nmap <C-j> <C-W>j
nmap <C-k> <C-W>k
nmap <C-h> <C-W>h
nmap <C-l> <C-W>l

" set relativenumber
map <silent><F3> :set relativenumber!<CR>

" Visual linewise up and down by default (and use gj gk to go quicker)
noremap <Up> gk
noremap <Down> gj
noremap j gj
noremap k gk

" Remap H and L (top, bottom of screen to left and right end of line)
nnoremap H ^
nnoremap L $
vnoremap H ^
vnoremap L g_

" Do not show stupid q: window
map q: :q

" Exit on j
imap jj <Esc>
