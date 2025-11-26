---@type vim.lsp.Config
local Config = {
	init_options = {
		baseUrl = vim.env.OPENAI_BASE_URL,
		apiKey = vim.env.OPENAI_API_KEY,
		model = vim.env.OPENAI_MODEL,
		collName = "testColl",
	},
	cmd = { "gideon" },
	settings = {
		baseUrl = vim.env.OPENAI_BASE_URL,
		apiKey = vim.env.OPENAI_API_KEY,
		model = vim.env.OPENAI_MODEL,
		collName = "testColl",
	},
	root_dir = vim.fs.root(0, { ".git" }),
	filetypes = { "go" },
}
return Config
