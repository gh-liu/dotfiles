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

_G.UserFoldText = foldtext

vim.opt.foldtext = [[luaeval('UserFoldText')()]]
