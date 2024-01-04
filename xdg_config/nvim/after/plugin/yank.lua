if false then
	return
end

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

local yankg = augroup("liu/yank_setting", { clear = true })
local cursor_pos
autocmd({ "VimEnter", "CursorMoved" }, {
	pattern = "*",
	callback = function()
		cursor_pos = vim.fn.getpos(".")
	end,
	group = yankg,
	desc = "Remember Current Cursor Position",
})
autocmd("TextYankPost", {
	pattern = "*",
	callback = function()
		if vim.v.event and vim.v.event.operator == "y" then
			vim.fn.setpos(".", cursor_pos)
		end
	end,
	group = yankg,
	desc = "Keep Cursor Position on Yank",
})
