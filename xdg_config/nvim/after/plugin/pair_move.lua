if false then
	return
end

---@param opts {next: function, prev:function}
local set_pair_move_func = function(opts)
	vim.notify("Move mode: Use ] or [ to move, any other char to abort: ", vim.log.levels.INFO)
	while true do
		vim.cmd.normal("zz")
		vim.cmd.redraw()

		local ok, keynum = pcall(vim.fn.getchar)
		if not ok then
			break
		end
		local key = string.char(keynum)

		local fn
		if key == "]" then
			fn = opts.next
		elseif key == "[" then
			fn = opts.prev
		else
			break
		end

		local jump_ok, err = pcall(fn)
		if not jump_ok then
			vim.notify(err, vim.log.levels.WARN)
		end
	end
	vim.notify("Move mode exited", vim.log.levels.INFO)
end

---@param key string
---@param opts {next: function, prev:function}
local setmap = function(key, opts)
	vim.keymap.set("n", "<leader>]" .. key, function()
		set_pair_move_func(opts)
	end)
end

setmap("l", {
	next = function()
		vim.cmd.normal("]l")
		-- vim.cmd("lnext")
	end,
	prev = function()
		vim.cmd.normal("[l")
		-- vim.cmd("lprev")
	end,
})
setmap("q", {
	next = function()
		vim.cmd.normal("]q")
		-- vim.cmd("cnext")
	end,
	prev = function()
		vim.cmd.normal("[q")
		-- vim.cmd("cprev")
	end,
})
setmap("c", {
	next = function()
		vim.cmd.normal("]c")
	end,
	prev = function()
		vim.cmd.normal("[c")
	end,
})
