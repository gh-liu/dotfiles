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

			local servers = {
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#rust_analyzer
				-- rustup component add rust-analyzer
				rust_analyzer = {
					-- https://rust-analyzer.github.io/manual.html#configuration
					settings = {
						["rust-analyzer"] = {
							checkOnSave = {
								command = "clippy",
							},
							lens = {
								enable = false,
								debug = { enable = false },
								run = { enable = false },
							},
							inlayHints = {
								maxLength = 25,
								closureStyle = "impl_fn",
								renderColons = true,
								bindingModeHints = { enable = false },
								chainingHints = { enable = true },
								closingBraceHints = {
									enable = false,
									minLines = 25,
								},
								closureCaptureHints = { enable = false },
								closureReturnTypeHints = { enable = "never" },
								discriminantHints = { enable = "never" },
								expressionAdjustmentHints = {
									enable = "never",
									hideOutsideUnsafe = false,
									mode = "prefix",
								},
								lifetimeElisionHints = {
									enable = true,
									-- enable = "never",
									useParameterNames = false,
								},
								parameterHints = { enable = true },
								reborrowHints = { enable = "never" },
								typeHints = {
									enable = true,
									hideClosureInitialization = false,
									hideNamedConstructor = false,
								},
							},
							completion = {
								callable = {
									snippets = "fill_arguments",
								},
							},
						},
					},
				},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#zls
				-- Download from https://github.com/zigtools/zls/releases
				zls = {
					-- https://github.com/zigtools/zls#configuration-options
					settings = {
						zls = {
							enable_inlay_hints = true,
							inlay_hints_show_variable_type_hints = true,
							inlay_hints_show_parameter_name = true,
							inlay_hints_show_builtin = true,
							inlay_hints_exclude_single_argument = false,
							inlay_hints_hide_redundant_param_names = true,
							inlay_hints_hide_redundant_param_names_last_token = true,
							enable_autofix = false,
							warn_style = true,
						},
					},
				},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#pyright
				-- @need-install: uv tool install --force pyright
				-- pyright = {
				-- 	-- https://github.com/microsoft/pyright/blob/main/docs/settings.md
				-- 	-- https://microsoft.github.io/pyright/#/settings
				-- 	on_init = function(...)
				-- 		require("liu.lsp.servers.pyright").on_init(...)
				-- 	end,
				-- 	settings = {
				-- 		python = {
				-- 			analysis = {
				-- 				autoSearchPaths = true,
				-- 				diagnosticMode = "openFilesOnly",
				-- 				useLibraryCodeForTypes = true,
				-- 			},
				-- 		},
				-- 	},
				-- },
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ts_ls
				-- @need-install: bun i -g typescript typescript-language-server
				ts_ls = {},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#bashls
				-- @need-install: bun i -g bash-language-server
				bashls = {},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#vimls
				-- @need-install: bun i -g vim-language-server
				vimls = {},
			}

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
