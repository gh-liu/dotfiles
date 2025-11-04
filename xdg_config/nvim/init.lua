if vim.fn.has("nvim-0.12") == 0 then
	vim.notify("Need nvim 0.12 or bigger", vim.log.levels.ERROR)
	return
end

require("liu.snacks_profiler")

vim.cmd.colorscheme("nord")

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("liu.config.options")
require("liu.config.keymaps")
require("liu.config.commands")
require("liu.config.autocmds")

require("liu.lazy")

require("liu.lsp")
require("liu.config.diagnostics")

vim.cmd("packadd nvim.difftool")
vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nohlsearch")
