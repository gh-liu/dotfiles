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
