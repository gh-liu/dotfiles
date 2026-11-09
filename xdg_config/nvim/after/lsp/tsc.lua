-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#tsc
---@type vim.lsp.Config
local Config = {
	settings = {
		["js/ts"] = {
			referencesCodeLens = {
				enabled = true,
				showOnAllFunctions = false
			}
		}
	}
}
return Config
