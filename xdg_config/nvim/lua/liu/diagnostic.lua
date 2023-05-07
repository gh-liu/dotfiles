-- https://neovim.io/doc/user/diagnostic.html
vim.diagnostic.config({
	underline = { severity = { min = vim.diagnostic.severity.INFO } },
	signs = { severity = { min = vim.diagnostic.severity.HINT } },
	float = { source = true, border = config.borders, show_header = false },
	severity_sort = true,
	virtual_text = false,
	update_in_insert = false,
})

vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "<leader>dd", vim.diagnostic.open_float)
-- vim.keymap.set("n", "<leader>dq", vim.diagnostic.setloclist)

vim.fn.sign_define("DiagnosticSignError", { text = config.icons.Error, texthl = "DiagnosticSignError" })
vim.fn.sign_define("DiagnosticSignWarn", { text = config.icons.Warn, texthl = "DiagnosticSignWarn" })
vim.fn.sign_define("DiagnosticSignInfo", { text = config.icons.Info, texthl = "DiagnosticSignInfo" })
vim.fn.sign_define("DiagnosticSignHint", { text = config.icons.Hint, texthl = "DiagnosticSignHint" })
