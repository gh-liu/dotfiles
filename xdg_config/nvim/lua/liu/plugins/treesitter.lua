local api = vim.api

---@diagnostic disable-next-line: missing-fields
require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"c",
		"lua",
		"vim",
		"vimdoc",
		"comment",
		"go",
		"gosum",
		"gomod",
		"gowork",
		"rust",
		"bash",
		"regex",
		"diff",
		"gitignore",
		"gitcommit",
		"git_rebase",
	},
	sync_install = false,
	auto_install = true,
	highlight = {
		enable = true,
		-- Disable slow treesitter highlight for large files
		disable = function(lang, buf)
			local max_filesize = 64 * 1024 -- 64 KB
			local ok, stats = pcall(vim.loop.fs_stat, api.nvim_buf_get_name(buf))
			if ok and stats and stats.size > max_filesize then
				return true
			end
		end,
	},
	indent = { enable = true },
	incremental_selection = { enable = false },
})

-- Navigation {{{1
-- copied from nvim-treesitter-refactor/navigation.lua
local ts_utils = require("nvim-treesitter.ts_utils")
local locals = require("nvim-treesitter.locals")

local M = {}

function M.goto_next_usage(bufnr)
	return M.goto_adjacent_usage(bufnr, 1)
end
function M.goto_previous_usage(bufnr)
	return M.goto_adjacent_usage(bufnr, -1)
end

local function index_of(tbl, obj)
	for i, o in ipairs(tbl) do
		if o == obj then
			return i
		end
	end
end

function M.goto_adjacent_usage(bufnr, delta)
	local bufnr = bufnr or api.nvim_get_current_buf()
	local node_at_point = vim.treesitter.get_node()
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
	ts_utils.goto_node(usages[target_index])
end

-- if lsp server supports document highlight, which will replce below two maps
vim.keymap.set("n", "]v", M.goto_next_usage)
vim.keymap.set("n", "[v", M.goto_previous_usage)
-- }}}

-- Rename {{{
-- copied from nvim-treesitter-refactor/smart_rename.lua
local get_node_text = vim.treesitter.get_node_text

local locals = require("nvim-treesitter.locals")

local function smart_rename(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	local node_at_point = vim.treesitter.get_node()
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
			local start_line, start_col, end_line, end_col = vim.treesitter.get_node_range(node)
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

-- if lsp server supports document rename, which will replce below map
vim.keymap.set("n", "<leader>rn", smart_rename)
-- }}}

-- vim: foldmethod=marker
