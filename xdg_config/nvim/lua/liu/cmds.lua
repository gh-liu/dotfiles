vim.api.nvim_create_user_command("FindAndReplace", function(opts)
	if #opts.fargs ~= 2 then
		vim.print("Two argument required.")
	end
	vim.api.nvim_command(string.format("silent cdo s/%s/%s", opts.fargs[1], opts.fargs[2]))
	vim.api.nvim_command("silent cfdo update")
end, {
	nargs = "*",
	desc = "Find and Replace (after quickfix)",
})

vim.api.nvim_create_user_command("Term", function(opts)
	vim.cmd("bo new")
	vim.cmd("resize " .. vim.fn.winheight(0) * 1 / 3)
	vim.cmd("term")

	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_option(buf, "ft", "term")

	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_option(win, "number", false)
	vim.api.nvim_win_set_option(win, "relativenumber", false)
	vim.api.nvim_win_set_option(win, "signcolumn", "no")
end, {
	desc = "Open Term Below",
})
