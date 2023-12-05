vim.filetype.add({
	extension = {},
	filename = {},
	pattern = {
		[".*/%.vscode/.*%.json"] = "jsonc",
	},
})
