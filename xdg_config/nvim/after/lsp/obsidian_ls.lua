---@type vim.lsp.Config
local Config = {
	cmd = { "obsidian_ls" },
	filetypes = { "markdown" },
	root_markers = { ".templates" },
	settings = {
		["obsidian"] = {
			ignores = {
				"^.templates/",
				"^blog/",
			},
		},
	},
}
return Config
