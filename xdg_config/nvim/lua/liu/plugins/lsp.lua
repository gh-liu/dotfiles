require("lspconfig.ui.windows").default_options.border = config.borders

local servers = {
	gopls = {
		-- https://github.com/golang/tools/blob/master/gopls/doc/settings.md
		gopls = {
			analyses = {
				nilness = true,
				shadow = true,
				unusedparams = true,
				unusewrites = true,
			},
			codelenses = {
				test = false,
			},
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
			gofumpt = true,
			staticcheck = true,
			semanticTokens = true,
			usePlaceholders = false,
			buildFlags = { "-tags", "debug" },
		},
	},
	rust_analyzer = {
		-- https://rust-analyzer.github.io/manual.html#configuration
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
		},
	},
	lua_ls = {
		-- https://github.com/LuaLS/lua-language-server/wiki/Settings
		Lua = {
			hint = { enable = true },
			format = { enable = false }, -- instead of using stylua
			telemetry = { enable = false },
			workspace = { checkThirdParty = false },
			diagnostics = { globals = { "vim" } },
		},
	},
	vimls = {},
	bashls = {},
	jsonls = {
		-- https://code.visualstudio.com/docs/getstarted/settings serach `json.`
		json = {
			format = { enable = true },
			schemas = {},
			validate = { enable = true },
		},
	},
	yamlls = {
		-- https://github.com/redhat-developer/yaml-language-server#language-server-settings
		yaml = {
			format = { enable = true },
			schemaStore = { enable = true },
			validate = { enable = true },
		},
	},
	tsserver = {},
	zls = {
		-- Download from https://zig.pm/zls/downloads/x86_64-linux/bin/zls
		-- https://github.com/zigtools/zls#configuration-options
		zls = {
			enable_inlay_hints = false,
			inlay_hints_show_builtin = true,
			inlay_hints_exclude_single_argument = true,
			inlay_hints_hide_redundant_param_names = false,
			inlay_hints_hide_redundant_param_names_last_token = false,
		},
	},
}

-- setup neodev BEFORE lspconfig
require("neodev").setup({
	setup_jsonls = false,
})

local on_attach = function(client, bufnr)
	-- local name = client.name
	-- vim.print(client.server_capabilities)
	-- vim.print(client.server_capabilities.executeCommandProvider)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local handlers = {}

for server_name, settings in pairs(servers) do
	local opts = {
		capabilities = capabilities,
		on_attach = on_attach,
		settings = settings,
		handlers = handlers,
	}

	require("lspconfig")[server_name].setup(opts)
end

set_hls({
	LspInfoList = { link = "Function" },
	LspInfoTip = { link = "Comment" },
	LspInfoTitle = { link = "Title" },
	LspInfoFiletype = { link = "Type" },
	LspInfoBorder = { link = "FloatBorder" },
})
