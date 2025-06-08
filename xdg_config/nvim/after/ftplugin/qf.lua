vim.cmd([[
let &l:statusline = '%q %{exists("w:quickfix_title") ? w:quickfix_title : ""} %= %l/%L'
]])

local info = vim.fn.getwininfo(vim.fn.win_getid())[1] or {}
vim.b.qf_is_loclist = info.loclist or 0
vim.b.qf_is_quickfix = info.quickfix or 0

if vim.b.qf_is_quickfix then
	vim.cmd("wincmd J")
end

local older = vim.cmd.colder
local newer = vim.cmd.cnewer
if not vim.b.qf_is_quickfix then
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

	---@type QFItem[]
	local items = {}
	if vim.b.qf_is_loclist == 1 then
		items = vim.fn.getloclist(0)
	else
		items = vim.fn.getqflist()
	end
	map("g<c-s>", function()
		local line = vim.fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				split_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a new horizontal window")
	map("g<c-v>", function()
		local line = vim.fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				vsplit_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a new vertical window")
	map("g<c-t>", function()
		local line = vim.fn.line(".")
		local item = items[line]
		tabedit_go_to(item.bufnr, item.lnum, item.col)
	end, "open entry in a new tab")
	map("g<c-p>", function()
		local line = vim.fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				pedit_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry in a preview window ")
	map("o", function()
		local line = vim.fn.line(".")
		local item = items[line]
		vim.schedule(function()
			call_in_the_last_accessed_win(function()
				drop_go_to(item.bufnr, item.lnum, item.col)
			end)
		end)
	end, "open entry and come back")
	map("O", function()
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
