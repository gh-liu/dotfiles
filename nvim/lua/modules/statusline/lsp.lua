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
	return vim.tbl_count(vim.diagnostic.get(0, { severity = svrt })),
		vim.tbl_count(vim.diagnostic.get(nil, { severity = svrt }))
end

function M.diagnostic_errors()
	local current, all = diagnostics(severities.Error)
	return current, all, signs.Error
end

function M.diagnostic_warnings()
	local current, all = diagnostics(severities.WARN)
	return current, all, signs.WARN
end

function M.diagnostic_info()
	local current, all = diagnostics(severities.INFO)
	return current, all, signs.INFO
end

function M.diagnostic_hints()
	local current, all = diagnostics(severities.HINT)
	return current, all, signs.HINT
end

return M
