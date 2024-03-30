if false then
	return
end

local api = vim.api
local fn = vim.fn
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

-- When toggling these, ignore error messages and restore the cursor to the original window when opening the list.
local silent_mods = { mods = { silent = true, emsg_silent = true } }
vim.keymap.set("n", "<leader>xq", function()
	if fn.getqflist({ winid = 0 }).winid ~= 0 then
		vim.cmd.cclose(silent_mods)
	elseif #fn.getqflist() > 0 then
		local win = api.nvim_get_current_win()
		vim.cmd.copen(silent_mods)
		if win ~= api.nvim_get_current_win() then
			vim.cmd.wincmd("p")
		end
	end
end, { desc = "Toggle quickfix list" })
vim.keymap.set("n", "<leader>xl", function()
	if fn.getloclist(0, { winid = 0 }).winid ~= 0 then
		vim.cmd.lclose(silent_mods)
	elseif #fn.getloclist(0) > 0 then
		local win = api.nvim_get_current_win()
		vim.cmd.lopen(silent_mods)
		if win ~= api.nvim_get_current_win() then
			vim.cmd.wincmd("p")
		end
	end
end, { desc = "Toggle location list" })

local QFTEXT = {}

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
		local width = fn.strdisplaywidth(str)
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
function QFTEXT.qftf(info)
	local qflist = info.quickfix == 1 and fn.getqflist({ id = info.id, items = 0 }).items
		or fn.getloclist(info.winid, { id = info.id, items = 0 }).items

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
			or fn.fnamemodify(api.nvim_buf_get_name(bufnr), ":~:.")
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

_G.nvim_qftf = QFTEXT.qftf

---See `:h 'quickfixtextfunc'`
vim.o.quickfixtextfunc = [[v:lua.nvim_qftf]]

local ACKMAP = {}

vim.g.qf_mapping_ack_style = 1
--[[ 
s - open entry in a new horizontal window
v - open entry in a new vertical window
t - open entry in a new tab
o - open entry and come back
O - open entry and close the location/quickfix window
p - open entry in a preview window 
]]

---@class QFItem
---@field bufnr integer
---@field col integer
---@field end_col integer
---@field lnum integer
---@field end_lnum integer
---@field module string
---@field nr integer
---@field pattern string
---@field text string
---@field type string
---@field valid integer
---@field vcol integer

function ACKMAP.setup()
	local function go_to(bufnr, mod, lnum, col)
		local fname = fn.bufname(bufnr)
		vim.cmd(string.format("%s +%d %s", mod, lnum, fname))
	end
	local function split_go_to(bufnr, lnum, col)
		local mod = "split"
		go_to(bufnr, mod, lnum, col)
	end
	local function vsplit_go_to(bufnr, lnum, col)
		local mod = "vsplit"
		go_to(bufnr, mod, lnum, col)
	end
	local function tabedit_go_to(bufnr, lnum, col)
		local mod = "tabedit"
		go_to(bufnr, mod, lnum, col)
	end
	local function pedit_go_to(bufnr, lnum, col)
		local mod = "pedit"
		go_to(bufnr, mod, lnum, col)
	end
	local function drop_go_to(bufnr, lnum, col)
		local mod = "drop"
		go_to(bufnr, mod, lnum, col)
	end

	local function call_in_the_last_accessed_win(fun)
		-- get the last accessed window
		local win = fn.win_getid(fn.winnr("#"))
		api.nvim_win_call(win, function()
			fun()
		end)
	end

	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { desc = desc, buffer = 0 })
	end

	---@type QFItem[]
	local items = {}
	if vim.b.qf_is_loclist == 1 then
		items = fn.getloclist(0)
	else
		items = fn.getqflist()
	end
	map("s", function()
		local line = fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				split_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a new horizontal window")
	map("v", function()
		local line = fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				vsplit_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a new vertical window")
	map("t", function()
		local line = fn.line(".")
		local item = items[line]
		tabedit_go_to(item.bufnr, item.lnum, item.col)
	end, "open entry in a new tab")
	map("p", function()
		local line = fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				pedit_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a preview window ")
	map("o", function()
		local line = fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				drop_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry and come back")
	map("O", function()
		local line = fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				drop_go_to(item.bufnr, item.lnum, item.col)
			end)

			if vim.b.qf_is_loclist == 1 then
				vim.cmd.lclose()
			else
				vim.cmd.cclose()
			end
		end)
	end, "open entry and close the location/quickfix window")
end

autocmd({ "FileType" }, {
	pattern = "qf",
	callback = function(ev)
		local buf = ev.buf
		local info = fn.getwininfo(fn.win_getid())[1] or {}
		vim.b.qf_is_loclist = info.loclist or 0
		vim.b.qf_is_quickfix = info.quickfix or 0
		ACKMAP.setup()
	end,
})

vim.g.qf_auto_quit = 1
autocmd({ "FileType" }, {
	pattern = "qf",
	callback = function(ev)
		local buf = ev.buf
		-- quit Vim if the last window is a quickfix window
		autocmd({ "BufEnter" }, {
			callback = function(ev)
				if vim.g.qf_auto_quit and fn.winnr("$") < 2 then
					vim.cmd.quit()
				end
			end,
			nested = true,
			buffer = buf,
		})
	end,
})
