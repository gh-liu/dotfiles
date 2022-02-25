-- local api = vim.api
local fn = vim.fn

local M = {}

M.format_file = function(cmd, flags)
	local current_file = vim.fn.expand("%")

	local stylua_command = string.format("%s %s %s ", cmd, flags, current_file)

	local output = fn.system(stylua_command)

	vim.cmd([[:e!]])
end
return M
