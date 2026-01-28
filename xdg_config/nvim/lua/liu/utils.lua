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

--- Creates a debounced function that delays execution until after `ms` milliseconds
--- have elapsed since the last invocation.
---@param ms number  Debounce delay in milliseconds
---@param fn function  Function to debounce
---@param opts? { cleanup?: boolean }  Options: if cleanup is true, returns a cleanup function
---@return function|(function, function)  Debounced function, or (debounced function, cleanup function) if opts.cleanup is true
local debounce = function(ms, fn, opts)
	opts = opts or {}
	local timer = vim.uv.new_timer()
	local is_pending = false

	local debounced = function(...)
		local argv = { ... }
		timer:stop()
		is_pending = true
		timer:start(ms, 0, function()
			timer:stop()
			is_pending = false
			vim.schedule_wrap(fn)(unpack(argv))
		end)
	end

	if opts.cleanup then
		local cleanup = function()
			if is_pending then
				timer:stop()
			end
			timer:close()
		end
		return debounced, cleanup
	end

	return debounced
end

return {
	set_cmds = set_cmds,
	augroup = augroup,
	float_opts = float_opts,
	debounce = debounce,
}
