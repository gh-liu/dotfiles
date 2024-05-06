local fn = vim.fn
local keymap = vim.keymap

-- https://neovim.io/doc/user/diagnostic.html
local diagnostic = vim.diagnostic
local min_serverity = diagnostic.severity.INFO
local opts = {
	underline = { severity = { min = min_serverity } },
	signs = {
		severity = { min = min_serverity },
		text = config.icons.diagnostics,
	},
	float = { source = true, border = config.borders, show_header = false },
	severity_sort = true,
	virtual_text = false,
	update_in_insert = false,
}
diagnostic.config(opts)

vim.g.disgnostic_sign_disable = false
keymap.set("n", "<leader>td", function()
	opts.signs = vim.g.disgnostic_sign_disable
	vim.g.disgnostic_sign_disable = not vim.g.disgnostic_sign_disable
	diagnostic.config(opts)
end)

-- for _, lhs in ipairs({ "<C-W>d", "<C-W><C-D>" }) do
-- 	keymap.set("n", lhs, function()
-- 		vim.diagnostic.open_float()
-- 	end, { desc = "Open a floating window showing diagnostics under the cursor" })
-- end

-- keymap.set("n", "d0", function()
-- 	local severity = vim.diagnostic.severity
-- 	local count = vim.v.count -- use count as level
-- 	local opts = {}
-- 	if severity.HINT >= count and count >= severity.ERROR then
-- 		opts.severity = count
-- 	end
-- 	diagnostic.setqflist(opts)
-- end, { desc = "[D]iagnostic [0]All" })
-- keymap.set("n", "dc", function()
-- 	local severity = vim.diagnostic.severity
-- 	local count = vim.v.count -- use count as level
-- 	local opts = {}
-- 	if severity.HINT >= count and count >= severity.ERROR then
-- 		opts.severity = count
-- 	end
-- 	diagnostic.setloclist(opts)
-- end, { desc = "[D]iagnostic [C]urrent Buffer" })

local diagnostic_goto = function(next, severity)
	local go = next and diagnostic.goto_next or vim.diagnostic.goto_prev
	severity = severity and diagnostic.severity[severity]
	return function()
		go({ severity = severity })
	end
end

local setmap = function(mode, lhs, rhs, opts)
	opts = opts or { silent = true, noremap = true }
	keymap.set(mode, lhs, rhs, opts)
end
-- setmap("n", "]d", diagnostic_goto(true))
-- setmap("n", "[d", diagnostic_goto(false))
setmap("n", "]e", diagnostic_goto(true, vim.diagnostic.severity.ERROR))
setmap("n", "[e", diagnostic_goto(false, vim.diagnostic.severity.ERROR))
setmap("n", "]w", diagnostic_goto(true, vim.diagnostic.severity.WARN))
setmap("n", "[w", diagnostic_goto(false, vim.diagnostic.severity.WARN))

local diagnostic_icons = config.icons.diagnostics
fn.sign_define("DiagnosticSignError", { text = diagnostic_icons.ERROR, texthl = "DiagnosticSignError" })
fn.sign_define("DiagnosticSignWarn", { text = diagnostic_icons.WARN, texthl = "DiagnosticSignWarn" })
fn.sign_define("DiagnosticSignInfo", { text = diagnostic_icons.INFO, texthl = "DiagnosticSignInfo" })
fn.sign_define("DiagnosticSignHint", { text = diagnostic_icons.HINT, texthl = "DiagnosticSignHint" })
