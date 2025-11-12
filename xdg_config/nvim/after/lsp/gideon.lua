---@type vim.lsp.Config
local Config = {
	init_options = {
		base_url = vim.env.OPENAI_BASE_URL,
		token = vim.env.OPENAI_API_KEY,
		model = vim.env.OPENAI_MODEL,
	},
	cmd = { "gideon" },
	settings = {
		base_url = vim.env.OPENAI_BASE_URL,
		token = vim.env.OPENAI_API_KEY,
		model = vim.env.OPENAI_MODEL,
	},
}
return Config
