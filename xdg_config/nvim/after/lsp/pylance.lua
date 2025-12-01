-- @need-install: bun install -g @delance/runtime
return {
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
