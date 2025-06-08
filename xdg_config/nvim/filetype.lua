vim.filetype.add({
	extension = {
		gotmpl = "gotmpl",
	},
	filename = {},
	pattern = {
		[".*/%.vscode/.*%.json"] = "jsonc",
	},
})
