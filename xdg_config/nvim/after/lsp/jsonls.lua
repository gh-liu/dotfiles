-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#jsonls
-- https://github.com/microsoft/vscode/tree/main/extensions/json-language-features/server
-- @need-install: bun i -g vscode-json-languageserver
return {
	cmd = { "vscode-json-languageserver", "--stdio" },
	-- https://code.visualstudio.com/docs/getstarted/settings serach `// JSON`
	-- https://github.com/microsoft/vscode/tree/main/extensions/json-language-features/server#settings
	settings = {
		json = {
			format = { enable = false },
			schemaDownload = { enable = true },
			schemas = require("liu.lsp.servers.jsonls").schemas,
			validate = { enable = true },
		},
	},
	filetypes = { "json", "jsonc" },
	on_attach = function(client, bufnr)
		-- require("liu.lsp.servers.jsonls").on_attach(client, bufnr)
	end,
}
