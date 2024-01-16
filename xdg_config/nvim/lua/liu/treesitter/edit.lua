local api = vim.api
local ts = vim.treesitter
local locals = require("nvim-treesitter.locals")

local M = {}

local get_node_text = ts.get_node_text

function M.smart_rename(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	local node_at_point = ts.get_node()
	if not node_at_point then
		return
	end
	local function complete_rename(new_name)
		-- Empty name cancels the interaction or ESC
		if not new_name or #new_name < 1 then
			return
		end

		local definition, scope = locals.find_definition(node_at_point, bufnr)
		local nodes_to_rename = {}
		nodes_to_rename[node_at_point:id()] = node_at_point
		nodes_to_rename[definition:id()] = definition

		for _, n in ipairs(locals.find_usages(definition, scope, bufnr)) do
			nodes_to_rename[n:id()] = n
		end

		local function node_to_lsp_range(node)
			local start_line, start_col, end_line, end_col = ts.get_node_range(node)
			local rtn = {}
			rtn.start = { line = start_line, character = start_col }
			rtn["end"] = { line = end_line, character = end_col }
			return rtn
		end

		local edits = {}
		for _, node in pairs(nodes_to_rename) do
			local lsp_range = node_to_lsp_range(node)
			local text_edit = { range = lsp_range, newText = new_name }
			table.insert(edits, text_edit)
		end
		vim.lsp.util.apply_text_edits(edits, bufnr, "utf-8")
	end

	if not node_at_point then
		vim.notify("No node to rename!", vim.log.levels.WARN)
		return
	end

	local node_text = get_node_text(node_at_point, bufnr)
	local input = { prompt = "New name: ", default = node_text or "" }
	if not vim.ui.input then
		local new_name = vim.fn.input(input.prompt, input.default)
		complete_rename(new_name)
	else
		vim.ui.input(input, complete_rename)
	end
end

return M
