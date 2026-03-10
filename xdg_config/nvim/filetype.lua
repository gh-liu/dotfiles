vim.filetype.add({
	extension = {
		gotmpl = "gotmpl",
		mdc = "markdown",
	},
	filename = {},
	pattern = {
		[".*/%.vscode/.*%.json"] = "jsonc",
	},
})
