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
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls
				-- Download from https://github.com/LuaLS/lua-language-server/releases
				lua_ls = {
					-- https://github.com/LuaLS/lua-language-server/wiki/Settings
					settings = {
						Lua = {
							hint = {
								enable = true,
								arrayIndex = "Disable",
							},
							format = { enable = false }, -- instead of using stylua
							telemetry = { enable = false },
							workspace = {
								library = { "$VIMRUNTIME/lua" },
							},
							completion = {
								-- https://github.com/LuaLS/lua-language-server/wiki/Settings#completioncallsnippet
								callSnippet = "Replace",
							},
						},
					},
					---@param client vim.lsp.Client
					on_init = function(client) end,
				},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#gopls
				-- @need-install: go install golang.org/x/tools/gopls@latest
				gopls = {
					-- https://github.com/golang/tools/blob/master/gopls/doc/settings.md
					settings = {
						gopls = {
							buildFlags = { "-tags", "debug" },
							gofumpt = true,
							-- https://github.com/golang/tools/blob/master/gopls/doc/settings.md#code-lenses
							codelenses = {
								test = false,
							},
							semanticTokens = true,
							usePlaceholders = true,
							-- https://github.com/golang/tools/blob/master/gopls/doc/analyzers.md
							analyses = {
								nilness = true,
								shadow = true,
								unusedparams = true,
								unusewrites = true,
							},
							-- https://staticcheck.dev/docs/checks
							staticcheck = true,
							-- https://github.com/golang/tools/blob/master/gopls/doc/inlayHints.md
							hints = {
								assignVariableTypes = true,
								compositeLiteralFields = true,
								compositeLiteralTypes = false,
								constantValues = true,
								functionTypeParameters = true,
								parameterNames = true,
								rangeVariableTypes = true,
							},
						},
					},
					on_attach = function(client, bufnr)
						require("liu.lsp.servers.gopls").on_attach(client, bufnr)
					end,
				},
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
				-- @need-install: bun i -g pyright
				pyright = {
					-- https://github.com/microsoft/pyright/blob/main/docs/settings.md
					-- https://microsoft.github.io/pyright/#/settings
					on_init = function(...)
						require("liu.lsp.servers.pyright").on_init(...)
					end,
					settings = {
						python = {
							analysis = {
								autoSearchPaths = true,
								diagnosticMode = "openFilesOnly",
								useLibraryCodeForTypes = true,
							},
						},
					},
				},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ruff
				-- @need-install: uv tool install --force ruff
				-- pip install ruff
				ruff = {},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#clangd
				-- sudo apt-get -y install clangd
				clangd = {
					filetypes = { "c", "cpp", "objc", "objcpp" },
				},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ts_ls
				-- @need-install: bun i -g typescript typescript-language-server
				ts_ls = {},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#yamlls
				-- @need-install: bun i -g yaml-language-server
				yamlls = {
					-- https://github.com/redhat-developer/yaml-language-server#language-server-settings
					settings = {
						yaml = {
							format = { enable = true },
							schemas = require("liu.lsp.servers.yamlls").schemas,
							schemaStore = { enable = true },
							validate = { enable = true },
						},
					},
					on_attach = function(client, bufnr)
						-- require("liu.lsp.servers.yamlls").on_attach(client, bufnr)
					end,
				},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#jsonls
				-- https://github.com/microsoft/vscode/tree/main/extensions/json-language-features/server
				-- @need-install: bun i -g vscode-json-languageserver
				jsonls = {
					cmd = { "vscode-json-languageserver", "--stdio" },
					-- https://code.visualstudio.com/docs/getstarted/settings serach `// JSON`
					-- https://github.com/microsoft/vscode/tree/main/extensions/json-language-features/server#settings
					settings = {
						json = {
							format = { enable = true },
							schemaDownload = { enable = true },
							schemas = require("liu.lsp.servers.jsonls").schemas,
							validate = { enable = true },
						},
					},
					on_attach = function(client, bufnr)
						-- require("liu.lsp.servers.jsonls").on_attach(client, bufnr)
					end,
				},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#taplo
				-- @need-install: cargo install --features lsp --locked taplo-cli
				taplo = {
					settings = {
						-- Use the defaults that the VSCode extension uses:
						-- https://github.com/tamasfe/taplo/blob/2e01e8cca235aae3d3f6d4415c06fd52e1523934/editors/vscode/package.json
						taplo = {
							configFile = { enabled = true },
							schema = {
								enabled = true,
								catalogs = { "https://www.schemastore.org/api/json/catalog.json" },
								cache = {
									memoryExpiration = 60,
									diskExpiration = 600,
								},
								-- Additional document and schema associations
								associations = {},
							},
						},
					},
				},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#bashls
				-- @need-install: bun i -g bash-language-server
				bashls = {},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ast_grep
				-- @need-install: cargo install ast-grep
				ast_grep = {},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#dockerls
				-- @need-install: bun i -g dockerfile-language-server-nodejs
				dockerls = {},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#vimls
				-- @need-install: bun i -g vim-language-server
				vimls = {},
				-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#buf_ls
				-- @need-install: go install github.com/bufbuild/buf/cmd/buf@latest
				buf_ls = {},
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
}
