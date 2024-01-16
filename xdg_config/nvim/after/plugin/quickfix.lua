if false then
	return
end

local M = {}

---Traverse the qflist and get the maximum display width of the
---transformed string; cache the transformed string and its width
---in table `str_cache` and `width_cache` respectively
---@param qflist any
---@param trans_fun fun(item: table): string|number
---@param max_width_allowed integer?
---@param str_cache table
---@param width_cache table
---@return integer
local function _traverse(qflist, trans_fun, max_width_allowed, str_cache, width_cache)
	max_width_allowed = max_width_allowed or math.huge
	local max_width_seen = 0
	for i, item in ipairs(qflist) do
		local str = tostring(trans_fun(item))
		local width = vim.fn.strdisplaywidth(str)
		str_cache[i] = str
		width_cache[i] = width
		if width > max_width_seen then
			max_width_seen = width
		end
	end
	return math.min(max_width_allowed, max_width_seen)
end

---See `:h quickfix-window-function`
---@param info table
---@return string[]
function M.qftf(info)
	local qflist = info.quickfix == 1 and vim.fn.getqflist({ id = info.id, items = 0 }).items
		or vim.fn.getloclist(info.winid, { id = info.id, items = 0 }).items

	if vim.tbl_isempty(qflist) then
		return {}
	end

	-- :h getqflist()
	local filename_str_cache = {}
	local lnum_str_cache = {}
	local col_str_cache = {}
	local type_str_cache = {}
	local nr_str_cache = {}

	local filename_width_cache = {}
	local lnum_width_cache = {}
	local col_width_cache = {}
	local type_width_cache = {}
	local nr_width_cache = {}

	---@param item table
	---@return string
	local function _fname_trans(item)
		local bufnr = item.bufnr
		local module = item.module
		local filename = item.filename
		return module and module ~= "" and module
			or filename and filename ~= "" and filename
			or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":~:.")
	end

	---@param item table
	---@return string|integer
	local function _lnum_trans(item)
		if item.lnum == item.end_lnum or item.end_lnum == 0 then
			return item.lnum
		end
		return string.format("%s-%s", item.lnum, item.end_lnum)
	end

	---@param item table
	---@return string|integer
	local function _col_trans(item)
		if item.col == item.end_col or item.end_col == 0 then
			return item.col
		end
		return string.format("%s-%s", item.col, item.end_col)
	end

	local type_signs = {
		E = "ERROR",
		W = "WARN",
		I = "INFO",
		N = "HINT",
	}

	---@param item table
	---@return string
	local function _type_trans(item)
		-- Sometimes `item.type` will contain unprintable characters,
		-- e.g. items in the qflist of `:helpg vim`
		local type = (type_signs[item.type] or item.type):gsub("[^%g]", "")
		return type == "" and "" or " " .. type
	end

	---@param item table
	---@return string
	local function _nr_trans(item)
		return item.nr <= 0 and "" or " " .. item.nr
	end

	local max_width = math.ceil(vim.go.columns / 2)
	-- stylua: ignore start
	local max_fname_width = _traverse(qflist, _fname_trans, max_width, filename_str_cache, filename_width_cache)
	local max_lnum_width  = _traverse(qflist, _lnum_trans, max_width, lnum_str_cache, lnum_width_cache)
	local max_col_width   = _traverse(qflist, _col_trans, max_width, col_str_cache, col_width_cache)
	local max_type_width  = _traverse(qflist, _type_trans, max_width, type_str_cache, type_width_cache)
	local max_nr_width    = _traverse(qflist, _nr_trans, max_width, nr_str_cache, nr_width_cache)
	-- stylua: ignore end

	---@return string
	local function _generate_qf_line(idx, item)
		if item.valid == 0 then
			return ""
		end

		local fname = filename_str_cache[idx]

		local lnum_col_are_zero = item.lnum == 0 and item.col == 0
		if lnum_col_are_zero and item.text == "" then
			return fname
		end

		local lnum = lnum_str_cache[idx]
		local col = col_str_cache[idx]
		local type = type_str_cache[idx]
		local nr = nr_str_cache[idx]

		local fname_cur_width = filename_width_cache[idx]
		local lnum_cur_width = lnum_width_cache[idx]
		local col_cur_width = col_width_cache[idx]
		local type_cur_width = type_width_cache[idx]
		local nr_cur_width = nr_width_cache[idx]

		if lnum_col_are_zero then
			return string.format(
				"%s│%s%s %s",
				fname .. string.rep(" ", max_fname_width - fname_cur_width),
				type .. string.rep(" ", max_type_width - type_cur_width),
				nr .. string.rep(" ", max_nr_width - nr_cur_width),
				item.text
			)
		end

		return string.format(
			"%s│%s:%s%s%s│ %s",
			fname .. string.rep(" ", max_fname_width - fname_cur_width),
			string.rep(" ", max_lnum_width - lnum_cur_width) .. lnum,
			col .. string.rep(" ", max_col_width - col_cur_width),
			type .. string.rep(" ", max_type_width - type_cur_width),
			nr .. string.rep(" ", max_nr_width - nr_cur_width),
			item.text
		)
	end

	local lines = {} ---@type string[]
	for i, item in ipairs(qflist) do
		local line = _generate_qf_line(i, item)
		table.insert(lines, line)
	end

	return lines
end

_G.nvim_qftf = M.qftf

---See `:h 'quickfixtextfunc'`
vim.o.quickfixtextfunc = [[v:lua.nvim_qftf]]

-- When toggling these, ignore error messages and restore the cursor to the original window when opening the list.
local silent_mods = { mods = { silent = true, emsg_silent = true } }
vim.keymap.set("n", "<leader>xq", function()
	if vim.fn.getqflist({ winid = 0 }).winid ~= 0 then
		vim.cmd.cclose(silent_mods)
	elseif #vim.fn.getqflist() > 0 then
		local win = vim.api.nvim_get_current_win()
		vim.cmd.copen(silent_mods)
		if win ~= vim.api.nvim_get_current_win() then
			vim.cmd.wincmd("p")
		end
	end
end, { desc = "Toggle quickfix list" })
vim.keymap.set("n", "<leader>xl", function()
	if vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 then
		vim.cmd.lclose(silent_mods)
	elseif #vim.fn.getloclist(0) > 0 then
		local win = vim.api.nvim_get_current_win()
		vim.cmd.lopen(silent_mods)
		if win ~= vim.api.nvim_get_current_win() then
			vim.cmd.wincmd("p")
		end
	end
end, { desc = "Toggle location list" })
