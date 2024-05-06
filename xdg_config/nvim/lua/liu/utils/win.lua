local M = {}

---@param win integer,
---@param fn fun(conf: vim.api.keyset.win_config): vim.api.keyset.win_config?
M.win_update_config = function(win, fn)
	local api = vim.api
	local config = api.nvim_win_get_config(win)
	local res = fn(config)
	if res ~= nil then
		config = res
	end
	api.nvim_win_set_config(win, config)
end

return M
