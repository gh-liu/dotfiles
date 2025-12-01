local common = require("liu.lsp.servers.pyright")
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#basedpyright
-- @need-install: uv tool install --force basedpyright
---@type vim.lsp.Config
local Config = {
	on_init = common.on_init,
	settings = {
		basedpyright = common.settings.python,
	},
}
return Config
