-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#pyright
-- @need-install: uv tool install --force pyright
---@type vim.lsp.Config
return {
	-- https://github.com/microsoft/pyright/blob/main/docs/settings.md
	-- https://microsoft.github.io/pyright/#/settings
	on_init = require("liu.lsp.servers.pyright").on_init,
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				diagnosticMode = "openFilesOnly",
				useLibraryCodeForTypes = true,
			},
		},
	},
}
