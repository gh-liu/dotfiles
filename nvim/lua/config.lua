local M = {}

-- General Settings
table.insert(M, {})

-- LSP

table.insert(M, {
	lsp_enabled = true,
	lsp_autostart_blacklist = { "sumneko_lua" },
	diagnostic_sign = {
		error = { sign = "E", hl = "DiagnosticSignError" },
		warn = { sign = "W", hl = "DiagnosticSignWarn" },
		info = { sign = "I", hl = "DiagnosticSignInfo" },
		hint = { sign = "H", hl = "DiagnosticSignHint" },
	},
})

-- Completion
table.insert(M, {})

-- Treesitter
table.insert(M, {})

return M
