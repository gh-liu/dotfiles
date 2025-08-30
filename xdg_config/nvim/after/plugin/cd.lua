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
