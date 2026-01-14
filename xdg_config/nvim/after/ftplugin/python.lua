vim.cmd.inoreabbrev("<buffer> true True")
vim.cmd.inoreabbrev("<buffer> false False")
vim.cmd.inoreabbrev("<buffer> null None")
vim.cmd.inoreabbrev("<buffer> none None")
vim.cmd.inoreabbrev("<buffer> nil None")

local python_project_root = vim.fs.root(0, { "pyproject.toml", "uv.lock", "requirements.txt", ".venv" })
vim.b.is_python_project = python_project_root ~= nil

if not vim.b.is_python_project then
	vim.b.dispatch = "uv run --script %"
end

vim.api.nvim_buf_create_user_command(0, "UvAdd", function(args)
	local parts = { "Dispatch", "uv", "add" }

	if not vim.b.is_python_project then
		parts[#parts + 1] = "--script"
		parts[#parts + 1] = "%"
	end

	for _, arg in ipairs(args.fargs) do
		parts[#parts + 1] = arg
	end

	vim.cmd(table.concat(parts, " "))
end, { nargs = "+", desc = "uv add (uses --script % outside projects)" })
