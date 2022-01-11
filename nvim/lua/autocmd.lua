local autocmd = require("utils").autocmd

autocmd("_general", {
	[[BufWinEnter * checktime]],
	[[TextYankPost * silent! lua vim.highlight.on_yank({higroup="IncSearch", timeout=150})]],
	[[FileType qf set nobuflisted ]],
	[[BufReadPost * normal! g`" ]],
}, true)

function helptab()
	if vim.o.buftype == "help" then
		vim.cmd([[wincmd T]])
		vim.api.nvim_buf_set_keymap("0", "n", "q", "<cmd>q<cr>", {
			silent = true,
			noremap = true,
		})
	end
end
autocmd("_open_help_tab", { [[BufEnter *.txt lua helptab()]] }, true)

-- filetype
local ncmd = vim.api.nvim_command("filetype plugin indent on")

autocmd("_protobuf", {
	[[ BufNewFile,BufRead *.proto setfiletype proto ]],
	[[ FileType proto setlocal shiftwidth=2 expandtab ]],
}, true)

autocmd("_json", { [[FileType json setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab ]] }, true)

autocmd("_markdown", { [[FileType markdown setlocal cole=0]] }, true)

autocmd("_tmux", { [[FileType tmux setlocal foldmethod=marker]] }, true)

autocmd("_go", { [[ BufNewFile,BufRead *.gotmpl set ft=gotmpl]] }, true)
