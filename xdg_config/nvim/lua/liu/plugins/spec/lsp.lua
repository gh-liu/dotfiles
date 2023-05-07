local lsp = {
	{
		"neovim/nvim-lspconfig",
		event = "VeryLazy",
		config = function()
			require("liu.lsp")

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
		"folke/neodev.nvim",
		event = "VeryLazy",
	},
	{
		"j-hui/fidget.nvim",
		enabled = false,
		event = "LspAttach",
		config = function()
			require("fidget").setup({
				sources = {
					["null-ls"] = {
						ignore = true,
					},
				},
			})

			set_hls({
				FidgetTask = { link = "Comment" },
				-- FidgetTitle = { link = "PreProc" },
			})
		end,
	},
	{
		"kosayoda/nvim-lightbulb",
		event = "LspAttach",
		config = function()
			vim.fn.sign_define(
				"LightBulbSign",
				{ text = config.icons.Hint, texthl = "WarningMsg", linehl = "", numhl = "" }
			)
			require("nvim-lightbulb").setup({ autocmd = { enabled = true } })
		end,
	},
	{
		"jose-elias-alvarez/null-ls.nvim",
		event = "VeryLazy",
		config = function()
			local nls = require("null-ls")
			local setup = nls["setup"]
			local builtins = nls["builtins"]
			local formatting = builtins["formatting"]
			local diagnostics = builtins["diagnostics"]
			local hover = builtins["hover"]
			local completion = builtins["completion"]
			local actions = builtins["code_actions"]

			-- local function filter_actions(title)
			-- 	return (nil == title:lower():match("blame"))
			-- end

			local sources = {
				-- actions.gitsigns.with({
				-- 	disabled_filetypes = { "harpoon" },
				-- 	config = { filter_actions = filter_actions },
				-- }),
				-- diagnostics.buf,
				-- formatting.buf,
				diagnostics.golangci_lint,
				-- diagnostics.selene,
				formatting.stylua,
				formatting.shfmt.with({
					filetypes = { "zsh", "sh" },
				}),
				-- formatting.fixjson,
			}
			return setup({ sources = sources, border = config.borders })
		end,
	},
}

return lsp
