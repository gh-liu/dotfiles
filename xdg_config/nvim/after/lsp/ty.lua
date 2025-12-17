-- https://docs.astral.sh/ty/features/language-server/#feature-reference
---@type vim.lsp.Config
-- @need-install: uv tool install --force ty
local Config = {
	settings = {
		-- https://docs.astral.sh/ty/reference/editor-settings/
		ty = {},
	},
}
return Config
