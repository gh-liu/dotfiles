-- save/quit {{{
vim.cmd([[
noremap <c-q> <cmd>quit<CR>
noremap <leader>q <cmd>quit<CR>
noremap <leader>Q <cmd>qall<CR>

noremap <leader>w <cmd>write<cr>
noremap <leader>W <cmd>wall<cr>

cabbr <expr> W (getcmdtype() is# ':' && getcmdline() is# 'W') ? 'w' : 'W'
cabbr <expr> Q (getcmdtype() is# ':' && getcmdline() is# 'Q') ? 'q' : 'Q'
]])
-- }}}
-- navigation {{{
vim.cmd([[
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
]])
-- }}}
-- coding {{{
vim.cmd([[
inoremap <c-c> <esc>
" select last inserted text.
nnoremap gV `[v`]

" :h Y-default
xnoremap Y <ESC>y$gv
" copy entire file contents (to gui-clipboard if available)
nnoremap <silent> yY :let b:winview=winsaveview() <bar> exe 'keepjumps keepmarks norm ggVG"+y' <bar> call winrestview(b:winview) <cr>

nnoremap dD :exe 'keepjumps keepmarks norm ggVG"+d' <cr>
" `bdelete` but keep window
"nnoremap d<leader> <cmd>buf#<bar>bd#<cr>
nnoremap d<leader> <cmd> if exists("*UserBufDelete") == 1 <bar> call UserBufDelete() <bar> else <bar> exec 'buf#<bar>bd#' <bar> endif <cr>

" delete the selection
snoremap <bs>  <C-o>"_s

" press . to repeat the last change
nnoremap gs mr:let @/='\<'.expand('<cword>').'\>'<CR>cgn
xnoremap gs mr"sy:let @/=@s<CR>cgn

" nice block
xnoremap <expr> I (mode()=~#'[vV]'?'<C-v>^o^I':'I')
xnoremap <expr> A (mode()=~#'[vV]'?'<C-v>0o$A':'A')

" Format whole buffer with formatprg without changing cursor position
"nnoremap gq= mzgggqG`z
nnoremap <silent> gq<leader> :let b:winview=winsaveview() <bar> exe 'keepjumps keepmarks norm ggVGgq' <bar> call winrestview(b:winview) <cr>
nnoremap gq? <Cmd>set formatprg? formatexpr?<CR>
]])
--}}}
-- tab/win/buffer {{{
vim.cmd([[
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
]])
-- }}}
-- path {{{
vim.cmd([[
" copy full path
"noremap y<cr> :execute 'let @+ = expand("%:p")' <Bar> echo 'copy:' @+ <CR>
" copy path:line
nnoremap y<leader> :execute 'let @+ = substitute(expand("%:p"), getcwd()."/", "", "") . ":" . line(".")' <Bar> echo 'copy:' @+ <CR>
" change directory
nnoremap cdc :lcd %:h<CR>
nnoremap cdu :lcd ..<CR>
nnoremap cdr :lcd <C-R>=luaeval('vim.fs.root(vim.fn.expand("%"), ".git")')<CR>
nnoremap cd- :lcd -<CR>
]])
-- }}}
-- tools {{{
vim.cmd([[
" print unix time at cursor as human-readable datetime. 1677604904 => '2023-02-28 09:21:45'
"nnoremap <C-G><C-T> :echo strftime('%Y-%m-%d %H:%M:%S', '<c-r><c-w>')<cr>
"nnoremap <C-G><C-T> :echo strftime('%Y-%m-%d %H:%M:%S', len(expand('<cword>')) > 10 ? str2nr(expand('<cword>')) / 1000 : str2nr(expand('<cword>')))<CR>
nnoremap g<C-T> :echo strftime('%Y-%m-%d %H:%M:%S', len(expand('<cword>')) > 10 ? str2nr(expand('<cword>')) / 1000 : str2nr(expand('<cword>')))<CR>

" insert formatted datetime (from @tpope vimrc).
inoremap <silent> <C-G><C-T> <C-R>=repeat(complete(col('.'),map(["%Y-%m-%d %H:%M:%S","%a, %d %b %Y %H:%M:%S %z","%Y %b %d","%d-%b-%y","%a %b %d %T %Z %Y","%Y%m%d"],'strftime(v:val)')+[localtime()]),0)<CR>

nnoremap g: :lua =

" jump to context
noremap cO m' <cmd> call search("\\v^[[:alpha:]$_]", "b", 1, 100) <cr>
" diff toggle
nnoremap dO :if &diff <bar> exec 'windo diffoff' <bar> else <bar> exec 'windo diffthis' <bar> endif<CR>


noremap z? <cmd> setlocal foldenable? 
\ <bar> setlocal foldlevel? 
\ <bar> setlocal foldmethod? 
\ <bar> setlocal foldexpr? 
\ <bar> setlocal foldmarker? 
\ <bar> setlocal foldtext? 
\ <cr>

"TODO position no ok
"noremap yqa <cmd> call setqflist(map(argv(),'{"bufnr":bufnr(v:val),"filename":v:val}')) <bar> copen <cr>
"noremap yA <cmd>argedit % <bar> argdedupe <bar> args  <cr>
"noremap yD <cmd>argdelete <bar> argdedupe <bar> args  <cr>
nnoremap <silent> yA
  \ :execute index(argv(), bufname('%')) >= 0 ?
  \ 'argdelete %' 
  \ :
  \ 'argadd % <Bar> argdedupe'
  \ <Bar>redrawstatus
  \ <CR>

noremap <leader>m <cmd>message<cr>

noremap [@ <cmd>colder<cr>
noremap ]@ <cmd>cnewer<cr>

if has("nvim")
	noremap ZR <cmd>restart<cr>
	noremap ZT <cmd>trust<cr>

	noremap zI <cmd>Inspect<cr>
end
]])
-- }}}
-- split {{{
vim.cmd([[
" _opt-in_ to sloppy-search https://github.com/neovim/neovim/issues/3209#issuecomment-133183790
nnoremap \e :edit **/
nnoremap \s :split **/
nnoremap \v :vsplit **/
"nnoremap \E :e <C-R>=expand("%:p:h") . "/**" <CR>
"nnoremap \S :split <C-R>=expand("%:p:h") . "/**" <CR>
"nnoremap \V :vsplit <C-R>=expand("%:p:h") . "/**" <CR>

cabbr <expr> E (getcmdtype() is# ':' && getcmdline() is# 'E') ? 'e' : 'E'
]])
-- }}}
-- search {{{
vim.cmd([[
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
]])
-- }}}
-- term {{{
vim.cmd([[
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

autocmd TermOpen * noremap <buffer> dq <cmd>bd!<cr>
]])
-- }}}

vim.cmd([[
" keep the old content
"xnoremap p "_dp
"xnoremap p "_c<esc>p
xnoremap p P
]])
-- Paste before/after linewise. See `:h put`
local cmd = vim.fn.has("nvim-0.12") == 1 and "iput" or "put"
vim.keymap.set({ "n", "x" }, "[p", '<Cmd>exe "' .. cmd .. '! " . v:register<CR>', { desc = "Paste Above" })
vim.keymap.set({ "n", "x" }, "]p", '<Cmd>exe "' .. cmd .. ' "  . v:register<CR>', { desc = "Paste Below" })

-- wrap {{{
local wrap_maps = vim.api.nvim_create_augroup("maps/wrap", { clear = true })
vim.api.nvim_create_autocmd("WinEnter", {
	group = wrap_maps,
	callback = function(ev)
		if vim.wo[0].wrap then
			local buffer = ev.buf
			vim.keymap.set("n", "j", "gj", { buffer = buffer })
			vim.keymap.set("n", "k", "gk", { buffer = buffer })
		end
	end,
})
vim.api.nvim_create_autocmd("OptionSet", {
	desc = "OptionSetWrap",
	group = wrap_maps,
	pattern = "wrap",
	callback = function(ev)
		local buffer = ev.buf
		if vim.v.option_new then
			vim.keymap.set("n", "j", "gj", { buffer = buffer })
			vim.keymap.set("n", "k", "gk", { buffer = buffer })
		else
			pcall(vim.keymap.del, "n", "j", { buffer = buffer })
			pcall(vim.keymap.del, "n", "k", { buffer = buffer })
		end
	end,
})
-- }}}

-- vim: set foldmethod=marker:
