-- :h default-mappings
---@param modes string|table
---@param lhs string
local unmap = function(modes, lhs)
	local modes_str = modes
	if type(modes) == "table" then
		modes_str = vim.iter(modes):join("")
	end
	if vim.fn.maparg(lhs, modes_str) ~= "" then
		vim.keymap.del(modes, lhs)
	end
end
-- disable `an/in` for lsp selectionRange
-- https://github.com/neovim/neovim/pull/34011#issue-3061662405
unmap("x", "in")
unmap({ "x" }, "an")
