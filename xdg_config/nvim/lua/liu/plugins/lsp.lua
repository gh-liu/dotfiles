require("lspconfig.ui.windows").default_options.border = config.borders

local servers = {
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#gopls
	-- go install golang.org/x/tools/gopls@latest
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
			require("liu.plugins.gopls").on_attach(client, bufnr)
		end,
	},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#rust_analyzer
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
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#lua_ls
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
				-- workspace = { checkThirdParty = false },
				-- diagnostics = { globals = { "vim" } },
				completion = {
					-- https://github.com/LuaLS/lua-language-server/wiki/Settings#completioncallsnippet
					callSnippet = "Replace",
				},
			},
		},
		---@param client lsp.Client
		on_init = function(client)
			local has_local_config = function(path)
				return vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc")
			end
			local path = client.workspace_folders and client.workspace_folders[1] and client.workspace_folders[1].name
			if not has_local_config(path) then
				client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
					Lua = {
						runtime = {
							version = "LuaJIT",
						},
						workspace = {
							checkThirdParty = false,
							library = {
								vim.env.VIMRUNTIME,
							},
						},
					},
				})
				client.notify(
					vim.lsp.protocol.Methods.workspace_didChangeConfiguration,
					{ settings = client.config.settings }
				)
			end

			return true
		end,
	},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#vimls
	-- npm install -g vim-language-server
	vimls = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#bashls
	-- npm i -g bash-language-server
	bashls = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#jsonls
	-- npm install -g vscode-langservers-extracted
	jsonls = {
		-- https://code.visualstudio.com/docs/getstarted/settings serach `json.`
		settings = {
			json = {
				format = { enable = true },
				schemas = {},
				validate = { enable = true },
			},
		},
	},
	html = {},
	cssls = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#yamlls
	-- npm install -g yaml-language-server
	yamlls = {
		-- https://github.com/redhat-developer/yaml-language-server#language-server-settings
		settings = {
			yaml = {
				format = { enable = true },
				schemaStore = { enable = true },
				validate = { enable = true },
			},
		},
	},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#tsserver
	-- npm install -g typescript typescript-language-server
	tsserver = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#zls
	-- Download from https://zig.pm/zls/downloads/x86_64-linux/bin/zls
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
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#pyright
	-- npm install -g pyright
	pyright = {
		-- https://microsoft.github.io/pyright/#/settings
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
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#ocamllsp
	-- opam install ocaml-lsp-server
	ocamllsp = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#marksman
	-- Download from https://github.com/artempyanykh/marksman/releases
	marksman = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#bufls
	-- go install github.com/bufbuild/buf-language-server/cmd/bufls@latest
	bufls = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#clangd
	-- sudo apt-get -y install clangd
	clangd = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#cmake
	-- pip install cmake-language-server
	cmake = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#taplo
	-- cargo install --features lsp --locked taplo-cli
	taplo = {},
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md#sqls
	-- go install github.com/sqls-server/sqls@latest
	sqls = {
		-- https://github.com/sqls-server/sqls#configuration-file-sample
		settings = {
			sqls = {
				connections = {},
			},
		},
		on_attach = function(client, bufnr)
			require("liu.plugins.sqls").on_attach(client, bufnr)
		end,
	},
}

-- setup neodev BEFORE lspconfig
local ok, neodev = pcall(require, "neodev")
if ok then
	neodev.setup({
		setup_jsonls = false,
		library = {
			runtime = true, -- runtime path
			types = false, -- full signature, docs and completion of vim.api, vim.treesitter, vim.lsp and others
		},
	})
end

local on_attach = function(client, bufnr)
	-- local name = client.name
	-- vim.print(client.server_capabilities)
	-- vim.print(client.server_capabilities.executeCommandProvider)
end

local capabilities = vim.tbl_deep_extend(
	"force",
	vim.lsp.protocol.make_client_capabilities(),
	-- nvim-cmp supports additional completion capabilities, so broadcast that to servers.
	require("cmp_nvim_lsp").default_capabilities(),
	{
		workspace = {
			-- PERF: didChangeWatchedFiles is too slow.
			-- TODO: Remove this when https://github.com/neovim/neovim/issues/23291#issuecomment-1686709265 is fixed.
			didChangeWatchedFiles = { dynamicRegistration = false },
		},
	}
)

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
