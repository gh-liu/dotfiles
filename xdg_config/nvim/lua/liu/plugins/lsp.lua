local config = require("liu.user_config")
local api = vim.api
-- local fn = vim.fn

---@param highlights table
local set_hls = function(highlights)
	for group, opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, group, opts)
	end
end

return {
	{
		"neovim/nvim-lspconfig",
		-- event = "VeryLazy",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"saghen/blink.cmp", -- NOTE: capabilities
		},
		config = function(self, opts)
			require("lspconfig.ui.windows").default_options.border = config.borders

			local servers = {}

			local other_caps = {}
			local ok, blink_cmp = pcall(require, "blink.cmp")
			if ok then
				other_caps = blink_cmp.get_lsp_capabilities()
			end

			local capabilities = vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), other_caps)
			for server_name, server_config in pairs(servers) do
				local default = {
					-- on_attach = on_attach,
					capabilities = capabilities,
					settings = {},
				}

				require("lspconfig")[server_name].setup(vim.tbl_deep_extend("force", default, server_config))
			end

			set_hls({
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
