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

if os.getenv("TMUX") == nil then
	-- disable in TMUX
	vim.api.nvim_create_autocmd("TextYankPost", {
		callback = function(ev)
			local text = vim.fn.getreg(vim.v.event.regname)
			require("vim.ui.clipboard.osc52").copy({ text })
		end,
	})
end

autocmd("TextYankPost", {
	desc = "Highlight when yanking",
	group = augroup("liu/highlight_yank", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({
			timeout = vim.o.updatetime,
			priority = vim.highlight.priorities.user + 1,
		})
	end,
})
