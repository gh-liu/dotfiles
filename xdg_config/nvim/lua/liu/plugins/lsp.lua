local api = vim.api
local utils = require("liu.utils")

return {
	{
		"neovim/nvim-lspconfig",
		-- event = "VeryLazy",
		event = { "BufReadPre", "BufNewFile" },
		config = function(self, opts)
			require("lspconfig.ui.windows").default_options.border = vim.o.winborder

			utils.set_hls({
				LspInfoList = { link = "Function" },
				LspInfoTip = { link = "Comment" },
				LspInfoTitle = { link = "Title" },
				LspInfoFiletype = { link = "Type" },
				LspInfoBorder = { link = "FloatBorder" },
			})
		end,
	},
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
