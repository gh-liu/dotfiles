local fn = vim.fn
local api = vim.api

local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local info = fn.getwininfo(fn.win_getid())[1] or {}
vim.b.qf_is_loclist = info.loclist or 0
vim.b.qf_is_quickfix = info.quickfix or 0

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

local aug = augroup("liu/qf", { clear = true })

-- quit Vim if the last window is a quickfix window
vim.g.qf_auto_quit = 1
autocmd({ "BufEnter" }, {
	callback = function(ev)
		if vim.g.qf_auto_quit and fn.winnr("$") < 2 then
			vim.cmd.quit()
		end
	end,
	group = aug,
	nested = true,
	buffer = 0,
})

vim.g.qf_mapping_ack_style = 1
--[[ 
s - open entry in a new horizontal window
v - open entry in a new vertical window
t - open entry in a new tab
o - open entry and come back
O - open entry and close the location/quickfix window
p - open entry in a preview window 
]]
do
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

-- Add the cfilter plugin.
vim.cmd.packadd("cfilter")
