local status_ok, _ = pcall(require, "lspconfig")
if not status_ok then
	return
end

require("config.lsp.handlers").setup()

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
require("config.lsp.settings.bashls")
require("config.lsp.settings.gopls")
require("config.lsp.settings.sumneko_lua")
require("config.lsp.settings.vimls")
