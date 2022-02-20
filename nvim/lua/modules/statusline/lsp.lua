local M = {}

local lsp = vim.lsp
-- local diagnostic = vim.diagnostic

local signs = {}
signs.Error = "  "
signs.WARN = "  "
signs.INFO = "  "
signs.HINT = "  "
signs.CLIENT = "  "

local severities = {}
severities.Error = vim.diagnostic.severity.ERROR
severities.WARN = vim.diagnostic.severity.WARN
severities.INFO = vim.diagnostic.severity.INFO
severities.HINT = vim.diagnostic.severity.HINT

function M.is_lsp_attached()
	return next(lsp.buf_get_clients(0)) ~= nil
end

function M.lsp_client_names()
	local clients = {}

	for _, client in pairs(lsp.buf_get_clients(0)) do
		clients[#clients + 1] = client.name
	end

	return table.concat(clients, " "), signs.CLIENT
end

local function diagnostics(svrt)
	return vim.tbl_count(vim.diagnostic.get(0, { severity = svrt }))
end

function M.diagnostic_errors()
	return diagnostics(severities.Error), signs.Error
end

function M.diagnostic_warnings()
	return diagnostics(severities.WARN), signs.WARN
end

function M.diagnostic_info()
	return diagnostics(severities.INFO), signs.INFO
end

function M.diagnostic_hints()
	return diagnostics(severities.HINT), signs.HINT
end

function M.get_info()
	local format_str =
		"%%#StatuslineLintError#%s %%#StatuslineLintWarn#%s %%#StatuslineLintChecking#%s %%#StatuslineLintOk#%s "
	local e, esign = M.diagnostic_errors()
	local w, wsign = M.diagnostic_warnings()
	local i, isign = M.diagnostic_info()
	local h, hsign = M.diagnostic_hints()

	return string.format(format_str, esign .. e, wsign .. w, isign .. i, hsign .. h)
end

return M
