if false then
	return
end

local api = vim.api

local M = {}

local function save_fixed_win_dims()
	local fixed_dims = {}

	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		if api.nvim_win_get_config(win).zindex == nil then
			local buf = api.nvim_win_get_buf(win)
			fixed_dims[win] = {
				width = api.nvim_win_get_width(win),
				height = api.nvim_win_get_height(win),
			}
		end
	end

	return fixed_dims
end

local function restore_fixed_win_dims(fixed_dims)
	for win, dims in pairs(fixed_dims) do
		if api.nvim_win_is_valid(win) then
			api.nvim_win_set_width(win, dims.width)
			api.nvim_win_set_height(win, dims.height)
		end
	end
end

local dims_wins = {}
function M.toggle_maximise()
	if #api.nvim_tabpage_list_wins(0) == 1 then
		vim.notify("only one", vim.log.levels.WARN, {})
		return
	end

	local win = api.nvim_get_current_win()
	local dims = dims_wins[win]
	if dims then
		restore_fixed_win_dims(dims)
		dims_wins[win] = nil
	else
		local dims = save_fixed_win_dims()
		dims_wins[win] = dims
		local width, height = vim.o.columns, vim.o.lines
		api.nvim_win_set_width(win, width)
		api.nvim_win_set_height(win, height)
	end
end

vim.keymap.set("n", "<leader>wm", M.toggle_maximise, {})

-- return M
