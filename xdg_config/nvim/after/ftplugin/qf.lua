-- Stack position label for the statusline: "[Quickfix 2/5]" / "[Location 1/3]".
-- getqflist({'nr': '$'}) returns the number of lists in the stack (the last list
-- number), getqflist({'nr': 0}) the position of the current list; lists are
-- capped by 'chistory'. Same for location lists with getloclist().
---@param winid? integer  window whose stack is queried, defaults to the current one
---@return string
local function qf_stack_label(winid)
	winid = winid or vim.api.nvim_get_current_win()
	local loclist = (vim.fn.getwininfo(winid)[1] or {}).loclist == 1
	local count, current
	if loclist then
		count = vim.fn.getloclist(winid, { nr = "$" }).nr
		current = vim.fn.getloclist(winid, { nr = 0, id = 0 }).nr
	else
		count = vim.fn.getqflist({ nr = "$" }).nr
		current = vim.fn.getqflist({ nr = 0, id = 0 }).nr
	end
	if count == 0 then
		return ""
	end
	return string.format("[%s %d/%d]", loclist and "Location" or "Quickfix", current, count)
end

-- referenced from the statusline below, evaluated on every redraw
_G.QF_STACK_LABEL = qf_stack_label

vim.cmd([[
setlocal signcolumn=no
let &l:statusline = '%#Title#%{v:lua.QF_STACK_LABEL()}%* %{exists("w:quickfix_title") ? w:quickfix_title : ""} %= %l/%L'
]])

local info = vim.fn.getwininfo(vim.fn.win_getid())[1] or {}
vim.b.qf_is_loclist = info.loclist or 0
vim.b.qf_is_quickfix = info.quickfix or 0

if vim.b.qf_is_quickfix then
	vim.cmd("wincmd J")
end

local older = vim.cmd.colder
local newer = vim.cmd.cnewer
-- NOTE: a location list window reports both loclist=1 and quickfix=1 in
-- getwininfo(), so test loclist explicitly instead of "not quickfix".
if vim.b.qf_is_loclist == 1 then
	older = vim.cmd.lolder
	newer = vim.cmd.lnewer
end
vim.keymap.set("n", "[f", function()
	pcall(older, { count = vim.v.count1 })
end, { buffer = 0 })
vim.keymap.set("n", "]f", function()
	pcall(newer, { count = vim.v.count1 })
end, { buffer = 0 })
local function echo_stack_warn(direction)
	local msg = "At the %s of the stack"
	vim.api.nvim_echo({ { msg:format(direction), "DiagnosticWarn" } }, false, {})
end
vim.keymap.set("n", "<", function()
	local ok, _ = pcall(older, { count = vim.v.count1 })
	if not ok then
		return echo_stack_warn("bottom")
	end
end, { desc = "Go to previous quickfix in history", nowait = true, buffer = 0 })
vim.keymap.set("n", ">", function()
	local ok, _ = pcall(newer, { count = vim.v.count1 })
	if not ok then
		return echo_stack_warn("top")
	end
end, { desc = "Go to next quickfix in history", nowait = true, buffer = 0 })

-- ack maps {{{1
local qf_mapping_ack_style = vim.g.qf_mapping_ack_style or 1

local ACKMAP = {}
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
		local fname = vim.fn.bufname(bufnr)
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
		local win = vim.fn.win_getid(vim.fn.winnr("#"))
		vim.api.nvim_win_call(win, function()
			fun()
		end)
	end

	local map = function(lhs, rhs, desc)
		vim.keymap.set("n", lhs, rhs, { desc = desc, buffer = 0 })
	end

	---@return QFItem[]
	local function get_items()
		if vim.b.qf_is_loclist == 1 then
			return vim.fn.getloclist(0)
		end
		return vim.fn.getqflist()
	end
	map("g<c-s>", function()
		local items = get_items()
		local line = vim.fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				split_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a new horizontal window")
	map("g<c-v>", function()
		local items = get_items()
		local line = vim.fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				vsplit_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a new vertical window")
	map("g<c-t>", function()
		local items = get_items()
		local line = vim.fn.line(".")
		local item = items[line]
		tabedit_go_to(item.bufnr, item.lnum, item.col)
	end, "open entry in a new tab")
	map("gK", function()
		local items = get_items()
		local line = vim.fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				pedit_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a preview window ")
	map("o", function()
		local items = get_items()
		local line = vim.fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				drop_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry and come back")
	map("O", function()
		local items = get_items()
		local line = vim.fn.line(".")
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

if qf_mapping_ack_style then
	ACKMAP.setup()
end
-- }}}
