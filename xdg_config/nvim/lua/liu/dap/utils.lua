local api = vim.api

local dap = require("dap")

local M = {}

local get_root = function()
	local root = vim.fs.root(0, ".git")
	if not root then
		root = vim.fn.getcwd(0)
	end
	return vim.fs.normalize(root)
end

local args_cache = {} ---@type table<string,table<string,boolean>>
setmetatable(args_cache, {
	__index = function(t, k)
		rawset(t, k, {})
		return t[k]
	end,
})

-- :h command-completion-custom
_G.DAP_ARGS_CACHE = function(ArgLead, CmdLine, CursorPos)
	return vim.tbl_keys(args_cache[get_root()])
end

M.args_fn = function()
	local args
	vim.ui.input({
		prompt = "Enter arguments: ",
		completion = "customlist,v:lua.DAP_ARGS_CACHE",
	}, function(input)
		args = input
	end)
	if not args then
		return dap.ABORT
	else
		args_cache[get_root()][args] = true
	end

	vim.cmd.stopinsert()
	return vim.split(args, " ")
end

M.closest_node = function(lang, query, captures)
	local parser = vim.treesitter.get_parser()
	local tree = parser:trees()[1]
	local query = vim.treesitter.query.get(lang, query)
	local closest_node, capture_name
	for _, match, _ in query:iter_matches(tree:root(), 0, 0, api.nvim_win_get_cursor(0)[1]) do
		for id, nodes in pairs(match) do
			for _, node in ipairs(nodes) do
				local name = query.captures[id]
				for _, cap in ipairs(captures) do
					if name == cap then
						closest_node = node
						capture_name = name
					end
				end
			end
		end
	end
	return closest_node, capture_name
end

M.filtered_pick_process = function()
	local opts = {}
	-- local input = vim.fn.input({
	-- 	prompt = "Search by process name (lua pattern), or hit enter to select from the process list: ",
	-- })
	-- opts["filter"] = input or ""
	return require("dap.utils").pick_process(opts)
end

---@alias liu.dap.console 'internalConsole'|'integratedTerminal'|'externalTerminal'|nil

---@class liu.dap.configuration
---@field name string
---@field type string
---@field request 'attach'|'launch'

M.enrich_config = function(config, on_config)
	config.options = { timeout = 10000 }
	vim.g.dap_last_config = config
	on_config(config)
end

return M
