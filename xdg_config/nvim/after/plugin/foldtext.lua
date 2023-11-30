-- " :h fold-foldtext
-- " v:foldstart	line number of first line in the fold
-- " v:foldend	line number of last line in the fold
-- " v:folddashes	a string that contains dashes to represent the foldlevel.
-- " v:foldlevel	the foldlevel of the fold

-- local function foldtext()
-- 	local result = vim.treesitter.foldtext()
-- 	if type(result) == "table" then
-- 	else
-- 		result = {}
-- 		local start_line = vim.fn.getline(vim.v.foldstart)
-- 		table.insert(result, { start_line, "Folded" })
-- 	end
-- 	table.insert(result, { " ...", "Folded" })
-- 	table.insert(result, { string.format(" +%s(%s)", vim.v.folddashes, vim.v.foldlevel), "Folded" })
-- 	table.insert(result, { string.format(" [%d lines]", vim.v.foldend - vim.v.foldstart), "Folded" })
-- 	return result
-- end

local api = vim.api
local ts = vim.treesitter

local function result2(result)
	local i = 1
	while i <= #result do
		-- find first capture that is not in current range and apply highlights on the way
		local j = i + 1
		while j <= #result and result[j].range[1] >= result[i].range[1] and result[j].range[2] <= result[i].range[2] do
			for k, v in ipairs(result[i][2]) do
				if not vim.tbl_contains(result[j][2], v) then
					table.insert(result[j][2], k, v)
				end
			end
			j = j + 1
		end

		-- remove the parent capture if it is split into children
		if j > i + 1 then
			table.remove(result, i)
		else
			-- highlights need to be sorted by priority, on equal prio, the deeper nested capture (earlier
			-- in list) should be considered higher prio
			if #result[i][2] > 1 then
				table.sort(result[i][2], function(a, b)
					return a[2] < b[2]
				end)
			end

			result[i][2] = vim.tbl_map(function(tbl)
				return tbl[1]
			end, result[i][2])
			result[i] = { result[i][1], result[i][2] }

			i = i + 1
		end
	end
	return result
end

---@return nil|{ [1]: string, [2]: string[], range: { [1]: integer, [2]: integer } }[] | { [1]: string, [2]: string[] }[]
local function make_result(bufnr, foldstart)
	---@type boolean, LanguageTree
	local ok, parser = pcall(ts.get_parser, bufnr)
	if not ok then
		return nil
	end

	local query = ts.query.get(parser:lang(), "highlights")

	if not query then
		return nil
	end

	local tree = parser:parse({ foldstart - 1, foldstart })[1]

	local line = api.nvim_buf_get_lines(bufnr, foldstart - 1, foldstart, false)[1]
	if not line then
		return nil
	end

	local result = {}

	local line_pos = 0

	for id, node, metadata in query:iter_captures(tree:root(), 0, foldstart - 1, foldstart) do
		local name = query.captures[id]
		local start_row, start_col, end_row, end_col = node:range()

		local priority = tonumber(metadata.priority or vim.highlight.priorities.treesitter)

		if start_row == foldstart - 1 and end_row == foldstart - 1 then
			-- check for characters ignored by treesitter
			if start_col > line_pos then
				table.insert(result, {
					line:sub(line_pos + 1, start_col),
					{},
					range = { line_pos, start_col },
				})
			end
			line_pos = end_col

			local text = line:sub(start_col + 1, end_col)
			table.insert(result, { text, { { "@" .. name, priority } }, range = { start_col, end_col } })
		end
	end
	return result
end

local function foldtext()
	local bufnr = api.nvim_get_current_buf()

	local foldstart = vim.v.foldstart
	local result = make_result(bufnr, foldstart)
	if not result then
		return vim.fn.foldtext()
	end
	local result = result2(result)

	table.insert(result, { "...", "Folded" })

	local foldend = vim.v.foldend
	local end_result = make_result(bufnr, foldend)
	if not end_result then
		return vim.fn.foldtext()
	end
	local end_result = result2(end_result)
	for index, value in ipairs(end_result) do
		table.insert(result, value)
	end

	table.insert(result, { string.format(" +%s(%s)", vim.v.folddashes, vim.v.foldlevel), "Folded" })
	table.insert(result, { string.format(" [%d lines]", vim.v.foldend - vim.v.foldstart), "Folded" })

	return result
end

_G.UserFoldText = foldtext

vim.opt.foldtext = [[luaeval('UserFoldText')()]]
