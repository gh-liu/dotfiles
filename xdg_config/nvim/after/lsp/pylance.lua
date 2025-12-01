-- @need-install: bun install -g @delance/runtime
---@type vim.lsp.Config
return {
	on_init = require("liu.lsp.servers.pyright").on_init,
	cmd = { "delance-langserver", "--stdio" },
	filetypes = { "python" },
	settings = {
		pyright = {
			-- disableOrganizeImports = true,
			-- disableTaggedHints = false,
		},
		python = {
			analysis = {
				autoSearchPaths = true,
				diagnosticMode = "workspace",
				-- typeCheckingMode = "standard",
				useLibraryCodeForTypes = true,
				-- diagnosticSeverityOverrides = {
				-- 	deprecateTypingAliases = false,
				-- },
				-- inlayHints = {
				-- 	callArgumentNames = "partial",
				-- 	functionReturnTypes = true,
				-- 	pytestParameters = true,
				-- 	variableTypes = true,
				-- },
			},
		},
	},
}
