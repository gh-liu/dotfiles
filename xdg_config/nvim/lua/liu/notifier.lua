local api = vim.api
local M = {}

local NS_NAME = "Notifier"
local NS_ID = vim.api.nvim_create_namespace("notifier")

local _bufnr = nil
local _winnr = nil

M._ui_valid = function()
	return _winnr and api.nvim_win_is_valid(_winnr) and _bufnr and api.nvim_buf_is_valid(_bufnr)
end

local width = function()
	return math.floor(vim.o.columns / 5)
end

M.create_win = function()
	if not _winnr or not api.nvim_win_is_valid(_winnr) then
		if not _bufnr or not api.nvim_buf_is_valid(_bufnr) then
			_bufnr = api.nvim_create_buf(false, true)
		end

		local border = "single"
		-- local border = "none"
		local success, winnr = pcall(api.nvim_open_win, _bufnr, false, {
			style = "minimal",
			border = border,
			focusable = false,
			zindex = 50,
			-- bottom-right corner
			relative = "editor",
			row = vim.o.lines - vim.o.cmdheight - 1,
			col = vim.o.columns - 1,
			anchor = "SE",
			width = width(),
			height = math.floor(vim.o.lines / 8),
			noautocmd = true,
		})
		if success then
			_winnr = winnr
		end
	end
end

M.delete_win = function()
	if _winnr and api.nvim_win_is_valid(_winnr) then
		api.nvim_win_close(_winnr, true)
	end
	_winnr = nil
end

local title = "gopls"
local lines = { "info1", "info2" }

M.redraw = function()
	if #lines == 0 then
		return
	end

	M.create_win()

	if not M._ui_valid() then
		return
	end

	api.nvim_buf_clear_namespace(_bufnr, NS_ID, 0, -1)

	vim.fn.strdisplaywidth("title")

	title = "   " .. title .. "   "
	api.nvim_buf_set_lines(_bufnr, 0, 1, false, { title })
	api.nvim_buf_add_highlight(_bufnr, NS_ID, "Title", 0, 0, -1)

	api.nvim_buf_set_lines(_bufnr, 1, -1, false, lines)
	for index, _ in ipairs(lines) do
		api.nvim_buf_add_highlight(_bufnr, NS_ID, "LspInlayHint", index, 0, -1)
	end

	-- api.nvim_win_set_width()
	api.nvim_win_set_height(_winnr, #lines + 1)

	vim.fn.timer_start(1000, function()
		M.delete_win()
	end)
end

return M
