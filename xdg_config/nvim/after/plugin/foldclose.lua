local function foldclose(node_types)
	local bufnr = vim.api.nvim_get_current_buf()
	local parser = vim.treesitter.get_parser(bufnr, vim.bo[bufnr].filetype)
	if not parser then
		return
	end
	local tree = parser:parse()[1]
	local root = tree:root()

	local types_str = vim.iter(node_types)
		:map(function(type_)
			return string.format("(%s)", type_)
		end)
		:join(" ")
	local query = string.format("[%s] @target_node", types_str)
	-- local patterns = {}
	-- for _, type in ipairs(node_types) do
	-- 	table.insert(patterns, string.format("(%s) @target_node", type))
	-- end
	-- local query = table.concat(patterns, "\n")
	local ts_query = vim.treesitter.query.parse(vim.bo[bufnr].filetype, query)
	if not ts_query then
		return
	end
	local nodes = {}
	for _, match, _ in ts_query:iter_matches(root, bufnr, 0, -1, { all = false }) do
		for _, node in pairs(match) do
			if node then
				table.insert(nodes, node)
			end
		end
	end

	-- local function find_nodes(node, types)
	-- 	local nodes = {}
	-- 	if vim.tbl_contains(types, node:type()) then
	-- 		table.insert(nodes, node)
	-- 	end
	-- 	for child in node:iter_children() do
	-- 		vim.list_extend(nodes, find_nodes(child, types))
	-- 	end
	-- 	return nodes
	-- end
	-- local nodes = find_nodes(root, node_types)
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

local ft_node_types = {
	go = { "import_declaration", "const_declaration" },
}

vim.api.nvim_create_autocmd("BufReadPost", {
	-- pattern = "*.go",
	callback = function(args)
		if vim.wo[0][0].foldmethod == "expr" and vim.wo[0][0].foldexpr == "v:lua.vim.treesitter.foldexpr()" then
			local node_types = ft_node_types[vim.bo[args.buf].filetype]
			if not node_types then
				return
			end

			-- vim.schedule(function()
			vim._with({ buf = args.buf }, function()
				foldclose(node_types)
			end)
			-- end)
		end
	end,
})
