-- https://thevaluable.dev/vim-create-text-objects/
-- vim.cmd([[
-- 	onoremap <silent> il :<c-u>normal! $v^<cr>
-- 	xnoremap <silent> il :<c-u>normal! $v^<cr>
-- 	onoremap <silent> al :<c-u>normal! $v0<cr>
-- 	xnoremap <silent> al :<c-u>normal! $v0<cr>
-- ]])

local fn = vim.fn

_G.textobj = {}

function textobj.select_indent(around)
	local start_indent = fn.indent(fn.line("."))
	local prev_line = fn.line(".") - 1

	while prev_line > 0 and fn.indent(prev_line) >= start_indent do
		vim.cmd("-")
		prev_line = fn.line(".") - 1
	end

	if around then
		vim.cmd("-")
	end

	vim.cmd("normal! 0V")

	local next_line = fn.line(".") + 1
	local last_line = fn.line("$")
	while next_line <= last_line and fn.indent(next_line) >= start_indent do
		vim.cmd("+")
		next_line = fn.line(".") + 1
	end
	if around then
		vim.cmd("+")
	end
end

local opts = { noremap = true, silent = true }
vim.keymap.set({ "x", "o" }, "ii", ":<c-u>lua textobj.select_indent()<cr>", opts)
vim.keymap.set({ "x", "o" }, "ai", ":<c-u>lua textobj.select_indent(true)<cr>", opts)
