local function foldtext()
	local result = vim.treesitter.foldtext()
	if type(result) == "table" then
		table.insert(result, { " ...", "NonText" })
		table.insert(result, { string.format(" +%s(%s)", vim.v.folddashes, vim.v.foldlevel), "NonText" })
		table.insert(result, { string.format(" [%d lines]", vim.v.foldend - vim.v.foldstart), "NonText" })
	end
	return result
end

_G.UserFoldText = foldtext

vim.opt.foldtext = [[luaeval('UserFoldText')()]]
