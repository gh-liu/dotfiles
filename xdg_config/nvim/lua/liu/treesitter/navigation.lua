local api = vim.api
local ts = vim.treesitter

local ts_utils = require("nvim-treesitter.ts_utils")
-- local parsers = require("nvim-treesitter.parsers")
local queries = require("nvim-treesitter.query")

local M = {}

---@param lang string
---@param query_group string
local function available_textobjects(lang, query_group)
	local parsed_queries = ts.query.get(lang, query_group)
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
---@param query_strings_regex string[]
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

---@param opts {query_strings_regex: string|string[], query_group: string, forward: boolean, start: boolean|nil, winid: number|nil}
local function ts_obj_move(opts)
	local forward = opts.forward
	local query_group = opts.query_group or "textobjects"
	local query_strings_regex = opts.query_strings_regex
	query_strings_regex = type(query_strings_regex) == "string" and { query_strings_regex } or query_strings_regex
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

	local winid = opts.winid or api.nvim_get_current_win()
	local bufnr = api.nvim_win_get_buf(winid)

	-- ts.language.get_lang(vim.api.nvim_get_option_value("filetype", { buf = bufnr }))
	local query_strings = get_query_strings_from_regex(
		query_strings_regex,
		query_group,
		ts.language.get_lang(api.nvim_get_option_value("filetype", { buf = bufnr }))
	)

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
		local row, col = unpack(api.nvim_win_get_cursor(winid))
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

local maps = {
	{ prefix = "]", forward = true },
	{ prefix = "[", forward = false },
}
--- map key with prefix `[` or`]` to move object
---@param key string
---@param query_strings_regex string|string[]
---@param start boolean
M.map_object_pair_move = function(key, query_strings_regex, start)
	local keymap = vim.keymap
	for _, value in pairs(maps) do
		keymap.set("n", value.prefix .. key, function()
			ts_obj_move({
				forward = value.forward,
				start = start,
				query_strings_regex = query_strings_regex,
				-- query_group = "textobjects",
			})
		end)
	end
end

return M
