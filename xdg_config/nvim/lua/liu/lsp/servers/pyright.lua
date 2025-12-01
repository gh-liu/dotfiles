local M = {}

---@return string
local venv_path = function()
	return vim.env.VIRTUAL_ENV or vim.fs.joinpath(vim.env.PWD, ".venv")
end

M.on_init = function(client, ...)
	-- https://github.com/microsoft/pyright/blob/main/docs/settings.md
	local venv = venv_path()
	if vim.fn.isdirectory(venv) == 1 then
		if not client.config.settings.python then
			client.config.settings.python = {}
		end
		client.config.settings.python.pythonPath = vim.fs.joinpath(venv, "bin", "python")
		client.config.settings.python.venvPath = venv
	end
end

return M
