" save/quit {{{
noremap <c-q> <cmd>quit<CR>
noremap <leader>q <cmd>quit<CR>
noremap <leader>Q <cmd>qall<CR>

noremap <leader>w <cmd>write<cr>
noremap <leader>W <cmd>wall<cr>

cabbr <expr> W (getcmdtype() is# ':' && getcmdline() is# 'W') ? 'w' : 'W'
cabbr <expr> Q (getcmdtype() is# ':' && getcmdline() is# 'Q') ? 'q' : 'Q'
" }}}
" navigation {{{
nnoremap gf gfzv
nnoremap gF gFzv

" do not need `zv` cause option `foldopen` contain serach
nnoremap <expr> n 'Nn'[v:searchforward]..'zz'
nnoremap <expr> N 'nN'[v:searchforward]..'zz'

nnoremap L Lzz
nnoremap H Hzz

nnoremap <c-d> <c-d>zz
nnoremap <c-u> <c-u>zz

nnoremap g, g,zvzz
nnoremap g; g;zvzz
"nmap g<C-o> g;
"nmap g<C-i> g,

nmap j gj
nmap k gk
" }}}
" yank/delete {{{
" :h Y-default
xnoremap Y <ESC>y$gv
" copy entire file contents (to gui-clipboard if available)
nnoremap <silent> yY :let b:winview=winsaveview() <bar> exe 'keepjumps keepmarks norm ggVG"+y' <bar> call winrestview(b:winview) <cr>

nnoremap dD :exe 'keepjumps keepmarks norm ggVG"+d' <cr>
" delete the selection
snoremap <bs>  <C-o>"_s

xnoremap x "_d
" keep the old content
xnoremap p P

" Paste before/after linewise. See `:h put`
if has('nvim-0.12')
  nnoremap [p <Cmd>exe "iput! " . v:register<CR>
  xnoremap [p <Cmd>exe "iput! " . v:register<CR>
  nnoremap ]p <Cmd>exe "iput "  . v:register<CR>
  xnoremap ]p <Cmd>exe "iput "  . v:register<CR>
else
  nnoremap [p <Cmd>exe "put! " . v:register<CR>
  xnoremap [p <Cmd>exe "put! " . v:register<CR>
  nnoremap ]p <Cmd>exe "put "  . v:register<CR>
  xnoremap ]p <Cmd>exe "put "  . v:register<CR>
endif
" }}}
" editing {{{
inoremap <c-c> <esc>
" select last inserted text.
nnoremap gV `[v`]

" press . to repeat the last change
nnoremap gs mr:let @/='\<'.expand('<cword>').'\>'<CR>cgn
xnoremap gs mr"sy:let @/=@s<CR>cgn

" nice block
xnoremap <expr> I (mode()=~#'[vV]'?'<C-v>^o^I':'I')
xnoremap <expr> A (mode()=~#'[vV]'?'<C-v>0o$A':'A')

" Format whole buffer with formatprg without changing cursor position
nnoremap <silent> gq<leader> :let b:winview=winsaveview() <bar> exe 'keepjumps keepmarks norm ggVGgq' <bar> call winrestview(b:winview) <cr>
nnoremap gq? <Cmd>set formatprg? formatexpr?<CR>
" }}}
" tab/win/buffer {{{
" switch to alternate buffer
"nnoremap <bs> <c-^>
"nnoremap <leader>bb <c-^>
"nnoremap <leader><tab> <c-^>
nnoremap z<leader> <c-^>

nnoremap <c-w>O <cmd>tabonly<cr>
nnoremap <silent> <C-w>Q :tabclose<CR>
nnoremap <silent> <C-w>z :wincmd z<Bar>cclose<Bar>lclose<CR>
nnoremap <silent> <C-w><C-z> :wincmd z<Bar>cclose<Bar>lclose<CR>

nnoremap <leader>t <cmd>tabnew <bar> tcd .<cr>
nnoremap <leader>1 1gt
nnoremap <leader>2 2gt
nnoremap <leader>3 3gt
nnoremap <leader>4 4gt
nnoremap <leader>5 5gt
nnoremap <leader>6 6gt

nnoremap [<tab> <cmd>tabprev<cr>
nnoremap ]<tab> <cmd>tabnext<cr>

" `bdelete` but keep window
nnoremap d<leader> <cmd> if exists("*UserBufDelete") == 1 <bar> call UserBufDelete() <bar> else <bar> exec 'buf#<bar>bd#' <bar> endif <cr>
" }}}
" path {{{
" copy full path
"noremap y<cr> :execute 'let @+ = expand("%:p")' <Bar> echo 'copy:' @+ <CR>
" copy path:line
nnoremap y<leader> :<C-u>let path = substitute(expand("%:p"), getcwd()."/", "", "") <Bar> let @+ = v:count > 0 ? path . ":" . line(".") : path  <Bar> echo 'copy:' @+ <CR>
" change directory
nnoremap cdc :lcd %:h<CR>
nnoremap cdu :lcd ..<CR>
nnoremap cdr :lcd <C-R>=luaeval('vim.fs.root(vim.fn.expand("%"), ".git")')<CR>
nnoremap cd- :lcd -<CR>
" }}}
" datetime {{{
" print unix time at cursor as human-readable datetime. 1677604904 => '2023-02-28 09:21:45'
nnoremap g<C-T> :echo strftime('%Y-%m-%d %H:%M:%S', len(expand('<cword>')) > 10 ? str2nr(expand('<cword>')) / 1000 : str2nr(expand('<cword>')))<CR>

" insert formatted datetime (from @tpope vimrc).
inoremap <silent> <C-G><C-T> <C-R>=repeat(complete(col('.'),map(["%Y-%m-%d %H:%M:%S","%a, %d %b %Y %H:%M:%S %z","%Y %b %d","%d-%b-%y","%a %b %d %T %Z %Y","%Y%m%d"],'strftime(v:val)')+[localtime()]),0)<CR>
" }}}
" fold {{{
" zN: If count is given, set foldlevel to count; otherwise restore previous fold state
nnoremap <expr> zN v:count > 0 ? printf('<Cmd>setlocal foldenable foldlevel=%d<CR>', v:count-1) : '<Cmd>setlocal foldenable<CR>'
" zm: If foldenable is off, open all folds first, then fold more
nnoremap <silent> zm :if &foldenable == 0 <bar> execute 'normal! zR' <bar> endif<CR>zm
noremap z? <cmd> setlocal foldenable? 
\ <bar> setlocal foldlevel? 
\ <bar> setlocal foldmethod? 
\ <bar> setlocal foldexpr? 
\ <bar> setlocal foldmarker? 
\ <bar> setlocal foldtext? 
\ <cr>
" }}}
" misc {{{
nnoremap g: :lua =

" jump to context
noremap cO m' <cmd> call search("\\v^[[:alpha:]$_]", "b", 1, 100) <cr>

nnoremap <silent> yA
  \ :execute index(argv(), bufname('%')) >= 0 ?
  \ 'argdelete %' 
  \ :
  \ 'argadd % <Bar> argdedupe'
  \ <Bar>redrawstatus
  \ <CR>

noremap <leader>m <cmd>message<cr>

if has("nvim")
	noremap ZR <cmd>restart<cr>
	noremap ZT <cmd>trust<cr>
	noremap zI <cmd>Inspect<cr>
end
" }}}
" split {{{
" _opt-in_ to sloppy-search https://github.com/neovim/neovim/issues/3209#issuecomment-133183790
nnoremap \e :edit **/
nnoremap \s :split **/
nnoremap \v :vsplit **/
"nnoremap \E :e <C-R>=expand("%:p:h") . "/**" <CR>
"nnoremap \S :split <C-R>=expand("%:p:h") . "/**" <CR>
"nnoremap \V :vsplit <C-R>=expand("%:p:h") . "/**" <CR>

cabbr <expr> E (getcmdtype() is# ':' && getcmdline() is# 'E') ? 'e' : 'E'
" }}}
" search {{{
" Mark position before search
nnoremap / ms/

" search current buffer and open results in loclist
"nnoremap \c   ms:<c-u>lvimgrep // % <bar> lw<s-left><s-left><s-left><s-left><right>
nnoremap \c   ms:<c-u>lgrep  % <bar> lw<s-left><s-left><s-left><s-left>

" search all files and open results in quickfix
"nnoremap \C mS:<c-u>noau vimgrep /\v\C/j **/*<s-left><left><left><left>

" Hit space to match multiline whitespace.
"cnoremap <expr> <Space> getcmdtype() =~ '[/?]' ? '\_s\+' : ' '
" fix cause abbr not expand
cnoremap <expr> <A-Space> getcmdtype() =~ '[/?]' ? '\_s\+' : ' '

" /<BS>: Inverse search (line NOT containing pattern).
"cnoremap <expr> <BS> (getcmdtype() =~ '[/?]' && getcmdline() == '') ? '\v^(()@!.)*$<Left><Left><Left><Left><Left><Left><Left>' : '<BS>'
" //: "Search within visual selection".
cnoremap <expr> / (getcmdtype() =~ '[/?]' && getcmdline() == '') ? "\<C-c>\<Esc>/\\%V" : '/'
" }}}
" term {{{
nnoremap `\ <cmd> vsplit <bar> term <cr>
nnoremap `- <cmd> bo split  <bar> term <cr>

tnoremap jk <C-\><C-n>
tnoremap <esc> <C-\><C-n>
tnoremap <C-g> <C-\><C-n>
"tnoremap <C-w> <C-\><C-n><C-w>

tnoremap <C-p> <Up>
tnoremap <C-n> <Down>
tnoremap <C-f> <Right>
tnoremap <C-b> <Left>
tnoremap <C-a> <Home>
tnoremap <C-e> <End>

tnoremap <C-q> <C-\><C-n>:quit<cr>

augroup liu_term_maps
  autocmd!
  autocmd TermOpen * noremap <buffer> dq <cmd>bd!<cr>
augroup END
" }}}

" vim: set foldmethod=marker:
