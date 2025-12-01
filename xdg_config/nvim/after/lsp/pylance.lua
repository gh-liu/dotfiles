local common = require("liu.lsp.servers.pyright")
-- @need-install: bun install -g @delance/runtime
---@type vim.lsp.Config
return {
	-- https://github.com/microsoft/pylance-release?tab=readme-ov-file#settings-and-customization
	on_init = common.on_init,
	cmd = { "delance-langserver", "--stdio" },
	filetypes = { "python" },
	settings = {
		pyright = {
			-- disableOrganizeImports = true,
			-- disableTaggedHints = false,
		},
		python = common.settings.python,
	},
}
