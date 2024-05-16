--- Get 'commentstring' at cursor
---@param ref_position integer[]|nil
---@return string
local function get_commentstring(ref_position)
	local buf_cs = vim.bo.commentstring

	local has_ts_parser, ts_parser = pcall(vim.treesitter.get_parser)
	if not has_ts_parser then
		return buf_cs
	end

	ref_position = ref_position or vim.api.nvim_win_get_cursor(0)

	-- Try to get 'commentstring' associated with local tree-sitter language.
	-- This is useful for injected languages (like markdown with code blocks).
	local row, col = ref_position[1] - 1, ref_position[2]
	local ref_range = { row, col, row, col + 1 }

	-- - Get 'commentstring' from the deepest LanguageTree which both contains
	--   reference range and has valid 'commentstring' (meaning it has at least
	--   one associated 'filetype' with valid 'commentstring').
	--   In simple cases using `parser:language_for_range()` would be enough, but
	--   it fails for languages without valid 'commentstring' (like 'comment').
	local ts_cs, res_level = nil, 0

	---@param lang_tree vim.treesitter.LanguageTree
	local function traverse(lang_tree, level)
		if not lang_tree:contains(ref_range) then
			return
		end

		local lang = lang_tree:lang()
		local filetypes = vim.treesitter.language.get_filetypes(lang)
		for _, ft in ipairs(filetypes) do
			local cur_cs = vim.filetype.get_option(ft, "commentstring")
			if cur_cs ~= "" and level > res_level then
				ts_cs = cur_cs
			end
		end

		for _, child_lang_tree in pairs(lang_tree:children()) do
			traverse(child_lang_tree, level + 1)
		end
	end
	traverse(ts_parser, 1)

	return ts_cs or buf_cs
end

return { get_commentstring = get_commentstring }
