local cache_fts = {} ---@type table<string,boolean>
vim.api.nvim_create_autocmd("FileType", {
	callback = function(event)
		local filetype = event.match
		if not cache_fts[filetype] then
			local lang = vim.treesitter.language.get_lang(filetype)
			if not lang then
				return
			end
			if vim.treesitter.query.get(lang, "foldclose") then
				cache_fts[filetype] = true
			end
		end
	end,
})

local function foldclose()
	local bufnr = vim.api.nvim_get_current_buf()
	local parser = vim.treesitter.get_parser(bufnr, vim.bo[bufnr].filetype)
	if not parser then
		return
	end
	local tree = parser:parse()[1]
	local root = tree:root()

	local ts_query = vim.treesitter.query.get(vim.bo[bufnr].filetype, "foldclose")
	if not ts_query then
		return
	end

	local nodes = {}
	for _, match, _ in ts_query:iter_matches(root, bufnr, 0, -1, { all = false }) do
		for _, node in pairs(match) do
			table.insert(nodes, node)
		end
	end

	if #nodes == 0 then
		return
	end

	for _, node in ipairs(nodes) do
		local start_row, _, end_row = node:range()
		local start = start_row + 1
		-- local end_ = end_row + 1
		vim._with({ win = 0 }, function()
			if vim.fn.foldclosed(start) == -1 then
				pcall(vim.cmd, start + 1 .. "foldclose")
			end
		end)
	end
end

vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(args)
		if not cache_fts[vim.bo[args.buf].filetype] then
			return
		end
		if not (vim.wo[0][0].foldmethod == "expr" or vim.wo[0][0].foldexpr == "v:lua.vim.treesitter.foldexpr()") then
			return
		end
		vim._with({ buf = args.buf }, function()
			foldclose()
		end)
	end,
})

vim.api.nvim_create_autocmd("LspNotify", {
	callback = function(args)
		if args.data.method == "textDocument/didOpen" then
			vim.lsp.foldclose("imports", vim.fn.bufwinid(args.buf))
		end
	end,
})
