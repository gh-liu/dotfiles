local api = vim.api

---@diagnostic disable-next-line: missing-fields
require("nvim-treesitter.configs").setup({
	ensure_installed = "all",
	ignore_install = {},
	-- ensure_installed = {
	-- 	"c",
	-- 	"lua",
	-- 	"vim",
	-- 	"vimdoc",
	-- 	"comment",
	-- 	"go",
	-- 	"gosum",
	-- 	"gomod",
	-- 	"gowork",
	-- 	"rust",
	-- 	"bash",
	-- 	"regex",
	-- 	"diff",
	-- 	"gitignore",
	-- 	"gitcommit",
	-- 	"git_rebase",
	-- },
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

-- local compat = require("nvim-treesitter.compat")
local parsers = require("nvim-treesitter.parsers")
local ts_utils = require("nvim-treesitter.ts_utils")
local queries = require("nvim-treesitter.query")
local locals = require("nvim-treesitter.locals")

-- Navigation {{{1
-- copied from nvim-treesitter-refactor/navigation.lua
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
	ts_utils.goto_node(usages[target_index], false, false)
end

-- if lsp server supports document highlight, which will replce below two maps
vim.keymap.set("n", "]v", M.goto_next_usage)
vim.keymap.set("n", "[v", M.goto_previous_usage)

vim.keymap.set("n", "]]", function()
	local node = ts_utils.get_node_at_cursor()
	if node ~= nil then
		ts_utils.goto_node(ts_utils.get_next_node(node, true, true), false, true)
	end
end, { desc = "Go to next sibling node" })

vim.keymap.set("n", "[[", function()
	local node = ts_utils.get_node_at_cursor()
	if node ~= nil then
		ts_utils.goto_node(ts_utils.get_previous_node(node, true, true), false, true)
	end
end, { desc = "Go to previous sibling node" })
-- }}}

-- Rename {{{
-- copied from nvim-treesitter-refactor/smart_rename.lua
local get_node_text = vim.treesitter.get_node_text

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

-- Object Move {{{1

---@param lang string
---@param query_group string
local function available_textobjects(lang, query_group)
	local parsed_queries = vim.treesitter.query.get(lang, query_group)
	if not parsed_queries then
		return {}
	end

	local found_textobjects = parsed_queries.captures or {}
	for _, pattern in pairs(parsed_queries.info.patterns) do
		for _, q in ipairs(pattern) do
			local query, arg1 = unpack(q)
			-- { "make-range!", "parameter.outer", 5, 16 }
			if query == "make-range!" and not vim.tbl_contains(found_textobjects, arg1) then
				table.insert(found_textobjects, arg1)
			end
		end
	end
	return found_textobjects
end

-- Get query strings from regex
---@param query_strings_regex table
---@param query_group string
---@param lang string
local function get_query_strings_from_regex(query_strings_regex, query_group, lang)
	local available_textobject_captures = available_textobjects(lang, query_group)
	local query_strings = {}
	for _, regex in ipairs(query_strings_regex) do
		for _, capture in ipairs(available_textobject_captures) do
			if string.match("@" .. capture, regex) then
				table.insert(query_strings, "@" .. capture)
			end
		end
	end

	return query_strings
end

---@param opts {query_strings_regex: string|table, query_group: string, forward: boolean, start: boolean|nil, winid: number|nil}
local function move(opts)
	local query_strings_regex = opts.query_strings_regex
	query_strings_regex = type(query_strings_regex) == "string" and { query_strings_regex } or query_strings_regex
	local query_group = opts.query_group or "textobjects"

	local forward = opts.forward
	local starts
	if opts.start == nil then
		starts = { true, false }
	else
		if opts.start then
			starts = { true }
		else
			starts = { false }
		end
	end

	local winid = opts.winid or vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_win_get_buf(winid)

	local query_strings = get_query_strings_from_regex(query_strings_regex, query_group, parsers.get_buf_lang(bufnr))

	-- score is a byte position.
	local function scoring_function(start_, match)
		local score, _
		if start_ then
			_, _, score = match.node:start()
		else
			_, _, score = match.node:end_()
		end
		if forward then
			return -score
		else
			return score
		end
	end

	local function filter_function(start_, match)
		local range = { match.node:range() }
		local row, col = unpack(vim.api.nvim_win_get_cursor(winid))
		row = row - 1 -- nvim_win_get_cursor is (1,0)-indexed

		if not start_ then
			if range[4] == 0 then
				range[1] = range[3] - 1
				range[2] = range[4]
			else
				range[1] = range[3]
				range[2] = range[4] - 1
			end
		end
		if forward then
			return range[1] > row or (range[1] == row and range[2] > col)
		else
			return range[1] < row or (range[1] == row and range[2] < col)
		end
	end

	for _ = 1, vim.v.count1 do
		local best_match
		local best_score
		local best_start
		for _, query_string in ipairs(query_strings) do
			for _, start_ in ipairs(starts) do
				---@diagnostic disable-next-line: missing-parameter
				local current_match = queries.find_best_match(bufnr, query_string, query_group, function(match)
					return filter_function(start_, match)
				end, function(match)
					return scoring_function(start_, match)
				end)

				if current_match then
					local score = scoring_function(start_, current_match)
					if not best_match then
						best_match = current_match
						best_score = score
						best_start = start_
					end
					if score > best_score then
						best_match = current_match
						best_score = score
						best_start = start_
					end
				end
			end
		end
		ts_utils.goto_node(best_match and best_match.node, not best_start, false)
	end
end

---@param key string
---@param query_strings_regex string
---@param start boolean
local map_move = function(key, query_strings_regex, start)
	vim.keymap.set("n", "]" .. key, function()
		move({
			forward = true,
			start = start,
			query_strings_regex = query_strings_regex,
			-- query_group = "textobjects",
		})
	end)
	vim.keymap.set("n", "[" .. key, function()
		move({
			forward = false,
			start = start,
			query_strings_regex = query_strings_regex,
			-- query_group = "textobjects",
		})
	end)
end
map_move("f", "@function.outer", true)
map_move("F", "@function.outer", false)
-- }}}

-- vim: foldmethod=marker
