-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#basedpyright
-- @need-install: uv tool install --force basedpyright
---@type vim.lsp.Config
local Config = {
	settings = {
		basedpyright = {
			analysis = {
				-- https://docs.basedpyright.com/latest/configuration/config-files/#type-check-diagnostics-settings
				---@alias SeverityOverridesValue 'error'|'warning'|'information'|'true'|'false'|'none'
				---@type table<string,SeverityOverridesValue>
				diagnosticSeverityOverrides = {
					reportAny = false,
				},
				useLibraryCodeForTypes = false,
				diagnosticMode = "workspace", ---@type 'openFilesOnly'|'workspace'
				typeCheckingMode = "standard", ---@type 'off'|'basic'|'standard'|'strict'|'recommended'|'all'
				stubPath = vim.fn.stdpath("data") .. "/lazy/python-type-stubs/stubs",
			},
		},
	},
}
return Config
