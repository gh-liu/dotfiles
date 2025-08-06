local api = vim.api

api.nvim_set_hl(0, "MarkSign", { link = "Title", default = true })
-- api.nvim_set_hl(0, "MarkSignPos", { default = true })

local ns = api.nvim_create_namespace("liu/marksigns")

--- @param bufnr integer
--- @param mark vim.fn.getmarklist.ret.item
local function decor_mark(bufnr, mark)
	local row = mark.pos[2] - 1
	pcall(api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
		sign_text = "'" .. mark.mark:sub(2),
		sign_hl_group = "MarkSign",
	})

	-- local col = mark.pos[3] - 1
	-- local off = mark.pos[4]
	-- pcall(api.nvim_buf_set_extmark, bufnr, ns, row, col, {
	-- 	end_col = col + off + 1,
	-- 	hl_group = "MarkSignPos",
	-- })
end

api.nvim_set_decoration_provider(ns, {
	on_win = function(_, _, bufnr, toprow, botrow)
		api.nvim_buf_clear_namespace(bufnr, ns, toprow, botrow)

		local current_file = api.nvim_buf_get_name(bufnr)

		local skip_marks = { "s" }
		-- Global marks
		for _, mark in ipairs(vim.fn.getmarklist()) do
			if mark.mark:match("%u") and not vim.tbl_contains(skip_marks, mark.mark:match("%u"), {}) then
				local mark_file = vim.fn.fnamemodify(mark.file, ":p:a")
				if current_file == mark_file then
					decor_mark(bufnr, mark)
				end
			end
		end

		-- Local marks
		for _, mark in ipairs(vim.fn.getmarklist(bufnr)) do
			if mark.mark:match("%l") and not vim.tbl_contains(skip_marks, mark.mark:match("%l"), {}) then
				decor_mark(bufnr, mark)
			end
		end
	end,
})

local redraw = function(mark)
	-- Redraw all win if global mark
	if mark:match("%u") then
		for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
			api.nvim__redraw({ win = win, range = { 0, -1 } })
		end
	else
		api.nvim__redraw({ range = { 0, -1 } })
	end
end

-- Redraw screen when marks are changed via `m` commands
vim.on_key(function(_, typed)
	local mark
	if typed:sub(1, 1) == "m" then
		mark = typed:sub(2)
	end
	if not mark then
		return
	end
	vim.schedule(function()
		redraw(mark)
	end)
end, ns)

vim.keymap.set("n", "dm", function()
	local mark = vim.fn.nr2char(vim.fn.getchar())
	vim.cmd("delmarks " .. mark)
	vim.schedule(function()
		redraw(mark)
	end)
end, { desc = "delete mark" })
-- vim.keymap.set("n", "M", "g`", { desc = "Jump to the exact location of a mark" })
