local M = {}

---@param client vim.lsp.Client
---@param bufnr integer
M.on_attach = function(client, bufnr)
	if settings then
		client.notify(vim.lsp.protocol.Methods.workspace_didChangeConfiguration, { settings = settings })
	end
end

-- https://github.com/microsoft/vscode/tree/main/extensions/json-language-features/server#settings
M.schemas = {
	{
		fileMatch = { ".vscode/launch.json" },
		url = "https://raw.githubusercontent.com/mfussenegger/dapconfig-schema/master/dapconfig-schema.json",
	},
	{
		fileMatch = { ".projections.json" },
		url = "https://raw.githubusercontent.com/gh-liu/dotfiles/refs/heads/master/schema/projectionist.json",
	},
	{
		fileMatch = { "snippets/*.json" },
		url = "https://raw.githubusercontent.com/Yash-Singh1/vscode-snippets-json-schema/main/schema.json",
	},
	{
		fileMatch = { ".golangci.json" },
		url = "https://golangci-lint.run/jsonschema/custom-gcl.jsonschema.json",
	},
}

return M
