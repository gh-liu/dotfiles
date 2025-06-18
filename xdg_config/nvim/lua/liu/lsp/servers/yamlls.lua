local M = {}

---@param client vim.lsp.Client
---@param bufnr integer
M.on_attach = function(client, bufnr)
	if settings then
		client.notify(vim.lsp.protocol.Methods.workspace_didChangeConfiguration, { settings = settings })
	end
end

-- https://github.com/redhat-developer/yaml-language-server?tab=readme-ov-file#using-yamlschemas-settings
M.schemas = {
	["https://raw.githubusercontent.com/ast-grep/ast-grep/main/schemas/project.json"] = {
		"sgconfig.yml",
	},
	--TODO https://raw.githubusercontent.com/ast-grep/ast-grep/refs/heads/main/schemas/rule.json
	["http://json.schemastore.org/github-workflow.json"] = ".github/workflows/*.{yml,yaml}",
	["http://json.schemastore.org/github-action.json"] = ".github/action.{yml,yaml}",
}

return M
