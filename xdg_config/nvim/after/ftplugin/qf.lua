vim.keymap.set("n", "<c-v>", "<c-w><cr><c-w>L", { buffer = 0 })
vim.keymap.set("n", "<c-x>", "<c-w><cr><c-w>K", { buffer = 0 })
vim.keymap.set("n", "<c-o>", "<cmd>wincmd p<cr>", { buffer = 0 })

local general = vim.api.nvim_create_augroup("UserQFSettings", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		if vim.fn.winnr("$") < 2 then
			vim.cmd.quit()
		end
	end,
	buffer = 0,
	group = general,
	desc = "Exit QF when it is the last window",
})
