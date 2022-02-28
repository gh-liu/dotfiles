return {
	cmd = { "gopls", "--remote=auto" },
	filetypes = { "go", "gomod", "gotmpl" },
	single_file_support = true,
	settings = {
		-- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
		gopls = {
			-- usePlaceholders = false,
			analyses = {
				unusedparams = true,
			},
			staticcheck = true,
			gofumpt = true,
		},
	},
	init_options = {
		usePlaceholders = true,
	},
}
