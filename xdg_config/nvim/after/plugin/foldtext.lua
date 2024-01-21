if true then
	return
end

-- " :h fold-foldtext
-- " v:foldstart	line number of first line in the fold
-- " v:foldend	line number of last line in the fold
-- " v:folddashes	a string that contains dashes to represent the foldlevel.
-- " v:foldlevel	the foldlevel of the fold

local function foldtext()
	local result = vim.treesitter.foldtext()
	if type(result) == "table" then
	else
		result = {}
		local start_line = vim.fn.getline(vim.v.foldstart)
		table.insert(result, { start_line, "Folded" })
	end
	table.insert(result, { " ...", "Folded" })
	table.insert(result, { string.format(" +%s(%s)", vim.v.folddashes, vim.v.foldlevel), "Folded" })
	table.insert(result, { string.format(" [%d lines]", vim.v.foldend - vim.v.foldstart), "Folded" })
	return result
end

local function get_ts_hl(row, col)
	-- 0 base row/col
	local hls = vim.inspect_pos(0, row, col, {
		treesitter = true,
		semantic_tokens = false,
		extmarks = false,
		syntax = false,
	})
	local ts_hls_len = #hls.treesitter
	if ts_hls_len == 0 then
		return "None"
	else
		return hls.treesitter[ts_hls_len].hl_group
	end
end

-- slow
local function fold_of_line(line)
	local result = {}
	local line_text = vim.fn.getline(line)

	local text = ""
	local cur_hl = get_ts_hl(line - 1, 0)
	local next_hl = nil
	for i = 1, #line_text do
		local char = string.sub(line_text, i, i)
		if i == #line_text then
			next_hl = "None"
		else
			next_hl = get_ts_hl(line - 1, i)
		end
		-- print(char .. " -- " .. cur_hl .. " -- " .. next_hl)
		if cur_hl == next_hl then
			text = text .. char
		else
			text = text .. char
			table.insert(result, { text, { cur_hl } })
			text = ""
		end
		cur_hl = next_hl
	end

	return result
end

local function foldtext2()
	local result = fold_of_line(vim.v.foldstart)
	table.insert(result, { " ...", "Folded" })
	table.insert(result, { string.format(" +%s(%s)", vim.v.folddashes, vim.v.foldlevel), "Folded" })
	table.insert(result, { string.format(" [%d lines]", vim.v.foldend - vim.v.foldstart), "Folded" })
	for index, value in ipairs(fold_of_line(vim.v.foldend)) do
		table.insert(result, value)
	end
	return result
end

-- _G.UserFoldText = foldtext2

_G.UserFoldText = foldtext

vim.opt.foldtext = [[luaeval('UserFoldText')()]]
