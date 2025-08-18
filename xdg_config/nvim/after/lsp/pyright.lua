-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#pyright
-- @need-install: uv tool install --force pyright
return {
	-- https://github.com/microsoft/pyright/blob/main/docs/settings.md
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
}
