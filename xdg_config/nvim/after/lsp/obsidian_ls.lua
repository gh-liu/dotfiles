---@type vim.lsp.Config
local Config = {
	cmd = { "/Users/liu/dev/golang/obsidian.go/obsidian-lsp" },
	filetypes = { "markdown" },
	root_markers = { ".templates" },
	settings = {
		["obsidian"] = {
			ignores = { "^blog/", "^.templates/" },
		},
	},
}
return Config
