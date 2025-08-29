local setmap = function(mode, lhs, rhs, opts)
	opts = opts or { silent = true, noremap = true }
	vim.keymap.set(mode, lhs, rhs, opts)
end

setmap("ca", "W", "((getcmdtype()  is# ':' && getcmdline() is# 'W')?('w'):('W'))", { expr = true })
setmap("ca", "Q", "((getcmdtype()  is# ':' && getcmdline() is# 'Q')?('q'):('Q'))", { expr = true })
setmap("ca", "E", "((getcmdtype()  is# ':' && getcmdline() is# 'E')?('e'):('E'))", { expr = true })

-- save/quit
vim.cmd([[
noremap <c-q> <cmd>quit<CR>
noremap <leader>q <cmd>quit<CR>
noremap <leader>Q <cmd>qall<CR>

noremap <leader>w <cmd>write<cr>
noremap <leader>W <cmd>wall<cr>
]])

-- jump
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

-- Coding
vim.cmd([[
inoremap <c-c> <esc>
" select last inserted text.
nnoremap gV `[v`]

" :h Y-default
xnoremap Y <ESC>y$gv

" keep the old content
"xnoremap p "_dp
"xnoremap p "_c<esc>p
xnoremap p P

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

-- Paste before/after linewise. See `:h put`
local cmd = vim.fn.has("nvim-0.12") == 1 and "iput" or "put"
vim.keymap.set({ "n", "x" }, "[p", '<Cmd>exe "' .. cmd .. '! " . v:register<CR>', { desc = "Paste Above" })
vim.keymap.set({ "n", "x" }, "]p", '<Cmd>exe "' .. cmd .. ' "  . v:register<CR>', { desc = "Paste Below" })

-- Tab/Win/Buffer
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

" window resize
nnoremap _ <c-w>-
nnoremap + <c-w>+
nnoremap <M-_> <c-w><
nnoremap <M-+> <c-w>>

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

-- path
vim.cmd([[
" copy full path
"noremap y<cr> :execute 'let @+ = expand("%:p")' <Bar> echo 'copy:' @+ <CR>
" copy path
nnoremap y<leader> :execute 'let @+ = substitute(expand("%:p"), getcwd()."/","","")' <Bar> echo 'copy:' @+ <CR>
" go to parent dir
"noremap - :<C-U>cd .. <CR>
]])

-- vim.keymap.set("n", "0cd", function()
-- 	local ok, _ = pcall(vim.cmd, "lcd -")
-- 	if not ok then
-- 		local gcwd = vim.fn.getcwd(-1, 0)
-- 		vim.cmd.lcd(gcwd)
-- 	end
-- end)
vim.keymap.set("n", "cd", function()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname == "" or vim.fn.filereadable(bufname) == 0 then
		bufname = vim.fn.getcwd()
	end
	local dirs = {}
	for dir in vim.fs.parents(bufname) do
		table.insert(dirs, dir)
	end
	-- dirs = vim.fn.reverse(dirs)
	local dir = dirs[vim.v.count1]
	if dir then
		vim.cmd.lcd(dirs[vim.v.count1])
	else
		local gcwd = vim.fn.getcwd(-1, 0)
		vim.cmd.lcd(gcwd)
	end
end)

-- Tools
vim.cmd([[
" print unix time at cursor as human-readable datetime. 1677604904 => '2023-02-28 09:21:45'
"nnoremap <C-G><C-T> :echo strftime('%Y-%m-%d %H:%M:%S', '<c-r><c-w>')<cr>
"nnoremap <C-G><C-T> :echo strftime('%Y-%m-%d %H:%M:%S', len(expand('<cword>')) > 10 ? str2nr(expand('<cword>')) / 1000 : str2nr(expand('<cword>')))<CR>
nnoremap g<C-T> :echo strftime('%Y-%m-%d %H:%M:%S', len(expand('<cword>')) > 10 ? str2nr(expand('<cword>')) / 1000 : str2nr(expand('<cword>')))<CR>

" insert formatted datetime (from @tpope vimrc).
inoremap <silent> <C-G><C-T> <C-R>=repeat(complete(col('.'),map(["%Y-%m-%d %H:%M:%S","%a, %d %b %Y %H:%M:%S %z","%Y %b %d","%d-%b-%y","%a %b %d %T %Z %Y","%Y%m%d"],'strftime(v:val)')+[localtime()]),0)<CR>


" copy entire file contents (to gui-clipboard if available)
nnoremap <silent> yY :let b:winview=winsaveview() <bar> exe 'keepjumps keepmarks norm ggVG"+y' <bar> call winrestview(b:winview) <cr>

nnoremap dD :exe 'keepjumps keepmarks norm ggVG"+d' <cr>

nnoremap g: :lua =

" jump to context
noremap cO m' <cmd> call search("\\v^[[:alpha:]$_]", "b", 1, 100) <cr>

" `bdelete` but keep window
"nnoremap d<leader> <cmd>buf#<bar>bd#<cr>
nnoremap d<leader> <cmd> if exists("*UserBufDelete") == 1 <bar> call UserBufDelete() <bar> else <bar> exec 'buf#<bar>bd#' <bar> endif <cr>

noremap z? <cmd> setlocal foldenable? 
\ <bar> setlocal foldlevel? 
\ <bar> setlocal foldmethod? 
\ <bar> setlocal foldexpr? 
\ <bar> setlocal foldmarker? 
\ <bar> setlocal foldtext? 
\ <cr>

"TODO position no ok
noremap yqa <cmd> call setqflist(map(argv(),'{"bufnr":bufnr(v:val),"filename":v:val}')) <bar> copen <cr>
noremap yA <cmd>argedit % <bar> argdedupe <bar> args  <cr>
noremap yD <cmd>argdelete <bar> argdedupe <bar> args  <cr>

noremap <leader>m <cmd>message<cr>

noremap [1 <cmd>lprev<cr>
noremap ]1 <cmd>lnext<cr>

noremap [@ <cmd>colder<cr>
noremap ]@ <cmd>cnewer<cr>
]])

-- Split
vim.cmd([[
" _opt-in_ to sloppy-search https://github.com/neovim/neovim/issues/3209#issuecomment-133183790
nnoremap \e :edit **/
nnoremap \s :split **/
nnoremap \v :vsplit **/
"nnoremap \E :e <C-R>=expand("%:p:h") . "/**" <CR>
"nnoremap \S :split <C-R>=expand("%:p:h") . "/**" <CR>
"nnoremap \V :vsplit <C-R>=expand("%:p:h") . "/**" <CR>
]])

-- Search
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

-- diff
vim.cmd([[
nnoremap dO :if &diff <bar> exec 'windo diffoff' <bar> else <bar> exec 'windo diffthis' <bar> endif<CR>
]])

-- term
vim.cmd([[
nnoremap `\ <cmd> vsplit <bar> term <cr>
nnoremap `- <cmd> split  <bar> term <cr>

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

autocmd TermOpen * noremap <buffer> dq <cmd>bd!<cr>
]])

-- neovim
vim.cmd([[
noremap ZR <cmd>restart<cr>
noremap ZT <cmd>trust<cr>
]])

-- :h default-mappings
---@param modes string|table
---@param lhs string
local unmap = function(modes, lhs)
	local modes_str = modes
	if type(modes) == "table" then
		modes_str = vim.iter(modes):join("")
	end
	if vim.fn.maparg(lhs, modes_str) ~= "" then
		vim.keymap.del(modes, lhs)
	end
end
-- disable `an/in` for lsp selectionRange
-- https://github.com/neovim/neovim/pull/34011#issue-3061662405
unmap("x", "in")
unmap({ "x" }, "an")

vim.keymap.set("n", "yoq", function()
	local get = function()
		for _, win in pairs(vim.fn.getwininfo()) do
			if win["quickfix"] == 1 then
				return true
			end
		end
		return false
	end

	if get() then
		vim.cmd("cclose")
	else
		vim.cmd("copen")
	end
end)
vim.keymap.set("n", "yoz", function()
	local option_name = "foldmethod"
	local option_values = { "manual", "indent", "expr", "marker", "syntax", "diff" }

	local option_value = vim.api.nvim_get_option_value(option_name, { scope = "local" })
	local idx = 0
	for i, value in ipairs(option_values) do
		if option_value == value then
			idx = i
		end
	end
	local idx1 = idx % #option_values + 1
	vim.api.nvim_set_option_value(option_name, option_values[idx1], { scope = "local" })
	vim.cmd([[setlocal ]] .. option_name .. "?")
end)

local toggle = function(key, option)
	vim.keymap.set("n", "yo" .. key, string.format("<cmd>setlocal %s! | setlocal %s? <cr>", option, option))
end
toggle("s", "spell")
toggle("w", "wrap")
toggle("d", "diff")
toggle("h", "hlsearch")
toggle("l", "list")
toggle("p", "previewwindow")
toggle("i", "ignorecase")
toggle("f", "winfixbuf")
