-- vim.keymap.set("n", "0cd", function()
-- 	local ok, _ = pcall(vim.cmd, "lcd -")
-- 	if not ok then
-- 		local gcwd = vim.fn.getcwd(-1, 0)
-- 		vim.cmd.lcd(gcwd)
-- 	end
-- end)

vim.keymap.set("n", "cd", function()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname == "" or vim.fn.filereadable(bufname) == 0 then
		bufname = vim.fn.getcwd()
	end
	local dirs = {}
	for dir in vim.fs.parents(bufname) do
		table.insert(dirs, dir)
	end
	-- dirs = vim.fn.reverse(dirs)
	local dir = dirs[vim.v.count1]
	if dir then
		vim.cmd.lcd(dirs[vim.v.count1])
	else
		local gcwd = vim.fn.getcwd(-1, 0)
		vim.cmd.lcd(gcwd)
	end
end)

vim.api.nvim_create_autocmd("DirChanged", {
	callback = function(ev)
		---@class DirChangedEvent
		---@field changed_window boolean
		---@field cwd string
		---@field scope 'global'|'tabpage'|'window'

		-- sessionoptions `globals` only String and Number types are stored.
		local dirs = vim.split(vim.g.UserDirs or "", ",", { trimempty = true })
		local event = vim.v.event ---@type DirChangedEvent
		local path = event.cwd
		table.insert(dirs, path)

		local tmp_dirs = {}
		vim.g.UserDirs = vim.iter(dirs)
			:filter(function(dir)
				if tmp_dirs[dir] then
					return false
				end
				tmp_dirs[dir] = true
				return true
			end)
			:join(",")
	end,
})

vim.api.nvim_create_user_command("Dir", function(args)
	local dirs = vim.split(vim.g.UserDirs or vim.fn.getcwd(), ",", { trimempty = true })
	local cwd = vim.fn.getcwd()
	dirs = vim.iter(dirs)
		:filter(function(dir)
			return dir ~= cwd
		end)
		:totable()

	vim.ui.select(dirs, {
		prompt = "lcd: ",
		format_item = function(item)
			-- local path = vim.fs.relpath(vim.fn.getcwd(-1, -1), item, {})
			-- return path or item
			return item
		end,
	}, function(dir)
		if dir then
			-- dir = vim.fs.abspath(dir)
			vim.cmd.lcd(dir)
		end
	end)
end, {})
