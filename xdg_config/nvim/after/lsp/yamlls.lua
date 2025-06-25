-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#yamlls
-- @need-install: bun i -g yaml-language-server
return {
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
}
