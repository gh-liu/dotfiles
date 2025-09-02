local cmd

-- @need-install: bun install -g @delance/runtime
if vim.fn.executable("delance-langserver") == 1 then
	cmd = { "delance-langserver", "--stdio" }
end

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#pyright
-- @need-install: uv tool install --force pyright
return {
	cmd = cmd,
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
