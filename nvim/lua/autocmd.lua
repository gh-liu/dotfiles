local autocmd = require("utils").autocmd

autocmd("misc_aucmds", {
	[[BufWinEnter * checktime]],
	[[TextYankPost * silent! lua vim.highlight.on_yank({higroup="IncSearch", timeout=150})]],
	[[FileType qf set nobuflisted ]],
	[[BufReadPost * normal! g`" ]],
}, true)

-- autocmd('packer_user_config', {[[BufWritePost plugins.lua source <afile> | PackerCompile]]}, true)
-- autocmd('packer_user_config', {[[BufWritePost init.lua source <afile> | PackerCompile]]}, true)

function helptab()
	if vim.o.buftype == "help" then
		vim.cmd([[wincmd T]])
		vim.api.nvim_buf_set_keymap("0", "n", "q", "<cmd>q<cr>", {
			silent = true,
			noremap = true,
		})
	end
end
autocmd("open_help_tab", { [[BufEnter *.txt lua helptab()]] }, true)
