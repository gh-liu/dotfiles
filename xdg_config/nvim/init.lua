-- =============================================================================
-- Environment Check
-- =============================================================================
if vim.fn.has("nvim-0.12") == 0 then
	vim.notify("Need nvim 0.12 or bigger", vim.log.levels.ERROR)
	return
end

-- =============================================================================
-- Basic Settings
-- =============================================================================
require("liu.snacks_profiler")
vim.cmd.colorscheme("nord")
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- =============================================================================
-- Core Neovim Config (immediate execution)
-- =============================================================================
local config_dir = vim.fn.stdpath("config")
vim.cmd("source " .. config_dir .. "/lua/liu/config/keymaps.vim")
vim.cmd("source " .. config_dir .. "/lua/liu/config/commands.vim")
require("liu.config.options")
require("liu.config.autocmds")

-- =============================================================================
-- Plugin Manager
-- =============================================================================
require("liu.lazy")

-- =============================================================================
-- Language Services
-- =============================================================================
require("liu.lsp")
require("liu.diagnostics")

-- =============================================================================
-- Built-in Plugins
-- =============================================================================
vim.cmd("packadd nvim.difftool")
vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nohlsearch")
