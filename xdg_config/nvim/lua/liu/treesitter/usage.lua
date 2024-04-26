local api = vim.api
local ts = vim.treesitter

local locals = require("nvim-treesitter.locals")
local ts_utils = require("nvim-treesitter.ts_utils")

local M = {}

local function index_of(tbl, obj)
	for i, o in ipairs(tbl) do
		if o == obj then
			return i
		end
	end
end

---@param bufnr integer
---@param delta integer
function M.goto_adjacent_usage(bufnr, delta)
	local bufnr = bufnr or api.nvim_get_current_buf()
	local node_at_point = ts.get_node()
	if not node_at_point then
		return
	end

	local def_node, scope = locals.find_definition(node_at_point, bufnr)
	local usages = locals.find_usages(def_node, scope, bufnr)

	local index = index_of(usages, node_at_point)
	if not index then
		return
	end

	local target_index = (index + delta + #usages - 1) % #usages + 1
	ts_utils.goto_node(usages[target_index], false, false)
end

M.goto_next = function()
	local bufnr = api.nvim_get_current_buf()
	return M.goto_adjacent_usage(bufnr, 1)
end
M.goto_prev = function()
	local bufnr = api.nvim_get_current_buf()
	return M.goto_adjacent_usage(bufnr, -1)
end

return {
	goto_next = M.goto_next,
	goto_prev = M.goto_prev,
}
