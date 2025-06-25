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
	-- NOTE: github workflow/action
	["https://www.schemastore.org/github-workflow.json"] = ".github/workflows/*.{yml,yaml}",
	["https://www.schemastore.org/github-action.json"] = ".github/action.{yml,yaml}",
	-- NOTE: golangci-lint https://golangci-lint.run/usage/configuration/
	["https://golangci-lint.run/jsonschema/custom-gcl.jsonschema.json"] = ".golangci.{yaml,yml}",
}

return M
