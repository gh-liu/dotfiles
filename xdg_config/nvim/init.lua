if vim.fn.has("nvim-0.11") == 0 then
	vim.notify("Need nvim 0.11 or bigger", vim.log.levels.ERROR)
	return
end

require("liu.flatten")

vim.cmd.colorscheme("nord")

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("liu.config.options")
require("liu.config.keymaps")
require("liu.config.configs")
require("liu.config.commands")
require("liu.config.autocmds")

require("liu.lazy")

require("liu.lsp")
