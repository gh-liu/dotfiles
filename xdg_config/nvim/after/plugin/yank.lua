if false then
	return
end

local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

autocmd("TextYankPost", {
	desc = "Highlight when yanking",
	group = augroup("liu/highlight_yank", { clear = true }),
	pattern = "*",
	callback = function()
		vim.hl.on_yank({
			timeout = vim.o.timeoutlen,
			priority = vim.hl.priorities.user + 1,
		})
	end,
})

-- :h yankring
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Yank-ring: store yanked text in registers 1-9.",
	callback = function()
		if vim.v.event.operator == "y" then
			for i = 9, 1, -1 do -- Shift all numbered registers.
				vim.fn.setreg(tostring(i), vim.fn.getreg(tostring(i - 1)))
			end
		end
	end,
})

local augroups = {}

augroups.keep_pos_yankpost = {
	save_cursor_position = {
		event = { "VimEnter", "CursorMoved" },
		callback = function()
			vim.b.cursor_pos = vim.fn.getpos(".")
		end,
	},
	yank_restore_cursor = {
		event = "TextYankPost",
		callback = function()
			if vim.v.event.operator == "y" then
				vim.fn.setpos(".", vim.b.cursor_pos)
			end
		end,
	},
}

for group, commands in pairs(augroups) do
	local augroup = vim.api.nvim_create_augroup("liu/" .. group, { clear = true })
	for _, opts in pairs(commands) do
		local event = opts.event
		opts.event = nil
		opts.group = augroup
		vim.api.nvim_create_autocmd(event, opts)
	end
end
