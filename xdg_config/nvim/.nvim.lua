vim.cmd([[
iabbr ni@ @need-install:
]])

vim.api.nvim_create_autocmd("BufReadPost", {
	pattern = { "*/plugins/*.lua" },
	callback = function(args)
		vim.api.nvim_buf_create_user_command(
			args.buf,
			"Plugins",
			[[vimgrep /\t\{2}"[a-zA-Z0-9-._]\+\/[a-zA-Z0-9-._]\+",/g % | copen]],
			{}
		)
		vim.wo[0][0].foldmethod = "expr"
		vim.wo[0][0].foldtext = "getline(v:foldstart+1)"
		vim.wo[0][0].foldexpr = "getline(v:lnum+1)=~'^\t\\{2}\"[a-zA-Z0-9-]\\+/[a-zA-Z0-9-]\\+'?'>1':'='"
	end,
})
