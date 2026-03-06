local api = vim.api
local utils = require("liu.utils")

return {
	-- Community configs for LSP clients providing quick setup for various language servers
	{
		"neovim/nvim-lspconfig",
	},
	-- Lightweight code action picker with UI for selecting and applying LSP code actions
	{
		"rachartier/tiny-code-action.nvim",
		lazy = true,
		init = function()
			vim.lsp.buf.code_action = function(...)
				require("tiny-code-action").code_action(...)
			end
		end,
		opts = {
			picker = {
				"buffer",
				opts = {
					auto_preview = true,
				},
			},
		},
	},
}
