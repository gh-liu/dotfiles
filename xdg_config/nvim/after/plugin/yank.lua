if false then
	return
end

local augroups = {}

-- :h vim.hl.on_yank
augroups.highlighting_yank = {
	highlighting_yank = {
		event = { "TextYankPost" },
		callback = function()
			vim.hl.on_yank({
				-- higroup = "Search",
				timeout = vim.o.timeoutlen,
				priority = vim.hl.priorities.user + 111,
			})
		end,
	},
}

-- :h yankring
augroups.yankring = {
	yankring = {
		event = { "TextYankPost" },
		callback = function()
			if vim.v.event.operator == "y" then
				for i = 9, 1, -1 do -- Shift all numbered registers.
					vim.fn.setreg(tostring(i), vim.fn.getreg(tostring(i - 1)))
				end
			end
		end,
	},
}

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
			if vim.v.event.operator == "y" and vim.b.cursor_pos then
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
