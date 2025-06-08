--:h terminal-debugger
-- vim.g.termdebug_wide = 1
vim.g.termdebug_config = {
	wide = 1,
	sign = "",
	map_minus = 0,
	map_plus = 0,
}

vim.api.nvim_create_autocmd("FileType", {
	pattern = "termdebug",
	callback = function()
		vim.keymap.set("n", "dq", "<cmd>bd!<cr>", { buffer = 0, noremap = true })
	end,
})
