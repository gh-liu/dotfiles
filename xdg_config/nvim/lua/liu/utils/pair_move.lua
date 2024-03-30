local M = {}

---@param opts {next: function|string, prev:function|string}
local set_pair_move_func = function(opts)
	local next = opts.next
	local prev = opts.prev
	vim.validate({
		next = { next, { "function", "string" } },
		prev = { prev, { "function", "string" } },
	})
	vim.notify("Move mode: Use ] or [ to move, any other char to abort: ", vim.log.levels.INFO)
	while true do
		vim.cmd.normal("zz")
		vim.cmd.redraw()

		local ok, keynum = pcall(vim.fn.getchar)
		if not ok then
			break
		end
		local key = string.char(keynum)

		local task
		if key == "]" then
			task = next
		elseif key == "[" then
			task = prev
		else
			break
		end

		local jump_ok, err
		local task_type = type(task)
		if task_type == "string" then
			jump_ok, err = pcall(vim.cmd.normal, task)
		end
		if task_type == "function" then
			jump_ok, err = pcall(task)
		end
		if not jump_ok then
			vim.notify(err, vim.log.levels.WARN)
		end
	end
	vim.notify("Move mode exited", vim.log.levels.INFO)
end

---@param key string
---@param opts {next: function|string, prev:function|string}
M.setkeymap = function(key, opts)
	vim.keymap.set("n", "<leader>]" .. key, function()
		set_pair_move_func(opts)
	end)
end

return M
