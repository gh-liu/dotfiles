-- Shared utility functions for plugin configurations

---@param cmds table<string, string|function>  Map of command names to their implementations
---@param opts? table  Optional command options (default: { bang = true, nargs = 0 })
local set_cmds = function(cmds, opts)
	opts = opts or { bang = true, nargs = 0 }
	for key, cmd in pairs(cmds) do
		vim.api.nvim_create_user_command(key, cmd, opts)
	end
end

---@param name string  Augroup name (will be prefixed with "liu/")
---@param clear? boolean  Whether to clear the group (default: true)
---@return integer  Augroup ID
local augroup = function(name, clear)
	return vim.api.nvim_create_augroup("liu/" .. name, { clear = clear ~= false })
end

---@return table  Standard float window options
local float_opts = function()
	return {
		border = vim.o.winborder,
		winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
	}
end

return {
	set_cmds = set_cmds,
	augroup = augroup,
	float_opts = float_opts,
}
