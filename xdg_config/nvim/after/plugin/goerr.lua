-- inspired by https://github.com/TheNoeTrevino/no-go.nvim
local ns = vim.api.nvim_create_namespace("conceal_goerr")

local err_identifier_pattern = "^(err|error)"
local virtual_text = " {{ERR}} 󱞿 "
local highlight = "NonText"

local function get_query_string(pattern)
	return [[
  (
    (if_statement
      condition: (binary_expression
        left: (identifier) @err_identifier
        right: (nil))
      consequence: (block
        (return_statement)))
    (#match? @err_identifier "]] .. pattern .. [[")
  )]]
end

local function conceal_iferr_node(bufnr, iferr_node, err_node)
	local start_row, start_col, end_row, _ = iferr_node:range()

	-- auto fold if block
	local cur_line = vim.fn.line(".")
	local start_line = start_row + 1
	local end_line = end_row + 1
	pcall(function()
		if
			vim.fn.mode() == "n" -- node range seems wrong in insert mode
			and vim.fn.foldclosed(start_line) == -1
			and (cur_line < start_line or cur_line > end_line)
		then
			vim.cmd(start_line .. "," .. end_line .. "foldclose")
		end
	end)

	-- check if cursor in the iferr node
	local cursor = vim.api.nvim_win_get_cursor(0)
	local cursor_row = cursor[1] - 1
	if cursor_row >= start_row and cursor_row <= end_row then
		return
	end

	local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
	if not line then
		return
	end
	local brace_col = line:find("{")
	if not brace_col then
		return
	end

	-- conceal lines
	vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, brace_col, {
		end_row = start_row,
		end_col = #line,
		conceal = "",
	})
	vim.api.nvim_buf_set_extmark(bufnr, ns, start_row + 1, 0, {
		end_row = end_row,
		end_col = 0,
		conceal_lines = "",
	})

	-- virtual text
	local err_text = vim.treesitter.get_node_text(err_node, bufnr)
	local virt_text = virtual_text:gsub("{{ERR}}", err_text)
	vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, brace_col, {
		virt_text = { { virt_text, highlight } },
		virt_text_pos = "inline",
	})
end

local function on_win(_, win, buf, top, bottom)
	local filetype = vim.bo[buf].filetype
	if filetype ~= "go" then
		return false
	end

	vim.wo[win][0].conceallevel = 2
	vim.wo[win][0].concealcursor = "nvic"

	vim.api.nvim_buf_clear_namespace(buf, ns, top, bottom)

	local parser = vim.treesitter.get_parser(buf, filetype)
	if not parser then
		return false
	end
	local trees = parser:parse()
	local tree = trees and trees[1]
	if not tree then
		return false
	end

	local query_str = get_query_string(err_identifier_pattern)
	local query = vim.treesitter.query.parse(filetype, query_str)
	for _, match, _ in query:iter_matches(tree:root(), buf, top, bottom + 1) do
		for id, nodes in pairs(match) do
			local capture_name = query.captures[id]
			if capture_name == "err_identifier" then
				local err_node = nodes[1]
				local if_node = err_node:parent()
				while if_node and if_node:type() ~= "if_statement" do
					if_node = if_node:parent()
				end
				if if_node then
					conceal_iferr_node(buf, if_node, err_node)
				end
			end
		end
	end
	return true
end

vim.api.nvim_set_decoration_provider(ns, { on_win = on_win })
