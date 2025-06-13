local setmap = function(mode, lhs, rhs, opts)
	opts = opts or { silent = true, noremap = true }
	vim.keymap.set(mode, lhs, rhs, opts)
end

setmap("n", "<C-q>", "<cmd>quit<CR>")
setmap("n", "<leader>q", "<cmd>quit<CR>")
setmap("n", "<leader>Q", "<cmd>qall<CR>")
setmap("n", "<leader>w", "<cmd>write<cr>")
setmap("n", "<leader>W", "<cmd>wall<cr>")
setmap("ca", "W", "((getcmdtype()  is# ':' && getcmdline() is# 'W')?('w'):('W'))", { expr = true })
setmap("ca", "Q", "((getcmdtype()  is# ':' && getcmdline() is# 'Q')?('q'):('Q'))", { expr = true })

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
]])

-- Coding
vim.cmd([[
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

" select last inserted text.
nnoremap gV `[v`]
" nice block
xnoremap <expr> I (mode()=~#'[vV]'?'<C-v>^o^I':'I')
xnoremap <expr> A (mode()=~#'[vV]'?'<C-v>0o$A':'A')

" Format whole buffer with formatprg without changing cursor position
"nnoremap gq= mzgggqG`z
nnoremap <silent> gq<leader> :let b:winview=winsaveview() <bar> exe 'keepjumps keepmarks norm ggVGgq' <bar> call winrestview(b:winview) <cr>
nnoremap gq? <Cmd>set formatprg? formatexpr?<CR>
]])

-- Tab/Win/Buffer
vim.cmd([[
" switch to alternate buffer
"nnoremap <bs> <c-^>
"nnoremap <leader>bb <c-^>
nnoremap <leader><tab> <c-^>

nnoremap <c-w>O <cmd>tabonly<cr>
nnoremap <silent> <C-w>Q :tabclose<CR>
nnoremap <silent> <C-w>z :wincmd z<Bar>cclose<Bar>lclose<CR>
nnoremap <silent> <C-w><C-z> :wincmd z<Bar>cclose<Bar>lclose<CR>

" window resize
nnoremap _ <c-w>-
nnoremap + <c-w>+
nnoremap <M-_> <c-w><
nnoremap <M-+> <c-w>>

nnoremap \t <cmd>tabnew <bar> tcd .<cr>
nnoremap \1 1gt
nnoremap \2 2gt
nnoremap \3 3gt
nnoremap \4 4gt
nnoremap \5 5gt
nnoremap \6 6gt
]])

-- path
vim.cmd([[
" copy full path
"noremap y<cr> :execute 'let @+ = expand("%:p")' <Bar> echo 'copy:' @+ <CR>
" copy path
noremap yY :execute 'let @+ = expand("%")' <Bar> echo 'copy:' @+ <CR>
" go to parent dir
"noremap - :<C-U>cd .. <CR>
]])

vim.keymap.set("n", "0cd", function()
	local ok, _ = pcall(vim.cmd, "lcd -")
	if not ok then
		local gcwd = vim.fn.getcwd(-1, 0)
		vim.cmd.lcd(gcwd)
	end
end)
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
nnoremap <silent> y<leader> :let b:winview=winsaveview() <bar> exe 'keepjumps keepmarks norm ggVG"+y' <bar> call winrestview(b:winview) <cr>

nnoremap d<leader> :exe 'keepjumps keepmarks norm ggVG"+d' <cr>

nnoremap g: :lua =

" jump to context
noremap gzo :call search("\\v^[[:alpha:]$_]", "b", 1, 100) <cr>

noremap gzn <cmd>lnext<cr>
noremap gzp <cmd>lprev<cr>
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
]])

vim.api.nvim_create_autocmd({ "TermOpen" }, {
	callback = function(args)
		local buf = args.buf
		vim.keymap.set("n", "dq", "<cmd>bd!<cr>", { buffer = buf, noremap = true })
	end,
})

-- https://github.com/justinmk/config/blob/5d4fd3d3d75daf6543596d412f1d0d01ad0f66be/.config/nvim/plugin/fug.lua#L92
local function ctrl_g()
	local fn = vim.fn

	local msg = {}
	local isfile = 0 == fn.empty(fn.expand("%:p"))
	-- Show file info.
	local oldmsg = vim.trim(fn.execute("norm! 2" .. vim.keycode("<c-g>")))
	local mtime = isfile and fn.strftime("%Y-%m-%d %H:%M", fn.getftime(fn.expand("%:p"))) or ""
	table.insert(msg, { ("%s  %s\n"):format(oldmsg:sub(1), mtime) })
	-- Show git branch
	local gitref = 1 == fn.exists("*FugitiveHead") and fn["FugitiveHead"](7) or nil
	if gitref then
		table.insert(msg, { ("branch: %s\n"):format(gitref) })
	end
	-- Show current directory.
	table.insert(msg, { ("dir: %s\n"):format(fn.fnamemodify(fn.getcwd(), ":~")) })
	-- Show current session.
	table.insert(
		msg,
		{ ("ses: %s\n"):format(#vim.v.this_session > 0 and fn.fnamemodify(vim.v.this_session, ":~") or "?") }
	)

	-- Show process id.
	table.insert(msg, { ("PID: %s\n"):format(fn.getpid()) })
	-- Show current context.
	-- https://git.savannah.gnu.org/cgit/diffutils.git/tree/src/diff.c?id=eaa2a24#n464
	local line = fn.search("\\v^[[:alpha:]$_]", "bn", 1, 100)
	table.insert(msg, {
		line .. ": " .. fn.getline(line),
		"Identifier",
	})
	vim.api.nvim_echo(msg, false, {})
end

vim.keymap.set("n", "<c-g>", ctrl_g)
-- vim: foldmethod=marker
