vim.keymap.set("n", "cD", function()
	local ft = vim.bo.filetype
	local lang = vim.treesitter.language.get_lang(ft)
	local query = vim.treesitter.query.get(lang, "declarations")
	if query then
		local parser = vim.treesitter.get_parser()
		local tree = parser:trees()[1]

		local line = vim.fn.line(".")
		for _, match, _ in query:iter_matches(tree:root(), 0, line, vim.api.nvim_win_get_cursor(0)[1]) do
			for id, nodes in pairs(match) do
				for _, node in ipairs(nodes) do
					-- local capture = query.captures[id]
					-- vim.print(vim.treesitter.get_node_text(node, 0))
					local start_row = vim.treesitter.get_range(node)[1]
					local start_line = start_row + 1
					vim.cmd("normal " .. start_line .. "G")
				end
			end
		end
	end
end, {})
