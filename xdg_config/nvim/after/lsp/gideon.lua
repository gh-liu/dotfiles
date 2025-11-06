---@type vim.lsp.Config
local Config = {
	cmd = { "uv", "run", vim.fn.expand("~/dev/gideon/main.py") },
	cmd_cwd = vim.fn.expand("~/dev/gideon"),
}
return Config
