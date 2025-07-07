-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#gopls
-- @need-install: go install golang.org/x/tools/gopls@latest
return {
	-- https://github.com/golang/tools/blob/master/gopls/doc/settings.md
	settings = {
		gopls = {
			buildFlags = { "-tags", "debug" },
			gofumpt = false,
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
}
