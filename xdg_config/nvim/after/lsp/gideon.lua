---@type vim.lsp.Config
local Config = {
	cmd = { "gideon" },
	settings = {
		base_url = vim.env.OPENAI_BASE_URL,
		token = vim.env.OPENAI_APIKEY,
		model = vim.env.OPENAI_MODEL,
	},
}
return Config
