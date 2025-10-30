local function foldclose(node_types)
	local bufnr = vim.api.nvim_get_current_buf()
	local parser = vim.treesitter.get_parser(bufnr, vim.bo[bufnr].filetype)
	if not parser then
		return
	end
	local tree = parser:parse()[1]
	local root = tree:root()

	local function find_nodes(node, types)
		local nodes = {}
		if vim.tbl_contains(types, node:type()) then
			table.insert(nodes, node)
		end
		for child in node:iter_children() do
			vim.list_extend(nodes, find_nodes(child, types))
		end
		return nodes
	end
	local nodes = find_nodes(root, node_types)
	if #nodes == 0 then
		return
	end

	for _, node in ipairs(nodes) do
		local start_row, _, end_row = node:range()
		local start = start_row + 1
		local end_ = end_row + 1
		if start < end_ then
			vim._with({ win = 0 }, function()
				if vim.fn.foldclosed(start) == -1 then
					pcall(vim.cmd, start + 1 .. "foldclose")
				end
			end)
		end
	end
end

vim.api.nvim_create_autocmd("BufReadPost", {
	pattern = "*.go",
	callback = function(args)
		if vim.wo[0][0].foldmethod ~= "expr" or vim.wo[0][0].foldexpr ~= "v:lua.vim.treesitter.foldexpr()" then
			return
		end
		vim.schedule(function()
			foldclose({ "import_declaration", "const_declaration" })
		end)
	end,
})
