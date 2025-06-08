local api = vim.api
local lsp = vim.lsp
local util = lsp.util
local ms = lsp.protocol.Methods

local M = {}

---@param symbols lsp.WorkspaceSymbol[] symbols
---@param kind lsp.SymbolKind kind
local filter_symbol = function(symbols, kind)
	return vim.iter(symbols)
		:filter(function(symbol)
			return symbol.kind == kind
		end)
		:totable()
end

---The parameters of a {@link WorkspaceSymbolRequest}.
---@class WorkspaceSymbolParams: lsp.WorkspaceSymbolParams
---
---A symbol kind to filter symbols by. Clients may send an empty
---string here to request symbols of all kind.
---@field kind? lsp.SymbolKind

---@param bufnr (integer) Buffer handle, or 0 for current.
---@param params WorkspaceSymbolParams workspace symbol params: query string or symbol kind to filter
---@param timeout_ms (integer|nil) Maximum time in milliseconds to wait for a
---                               result. Defaults to 1000
---
---@return table<integer, {err: lsp.ResponseError, result: any}>|nil (table) result Map of client_id:request_result.
---@return string|nil err On timeout, cancel, or error, `err` is a string describing the failure reason, and `result` is nil.
M.workspace_symbol = function(bufnr, params, timeout_ms)
	local resp, err = vim.lsp.buf_request_sync(bufnr, ms.workspace_symbol, params, timeout_ms)
	if not resp or err then
		return resp, err
	end

	if not params.kind then
		return resp, err
	end

	local ret = {}
	for client_id, request_result in pairs(resp) do
		if not request_result.err then
			---@type lsp.WorkspaceSymbol[]
			local symbols = request_result.result
			request_result.result = filter_symbol(symbols, params.kind)
		end
		ret[client_id] = request_result
	end
	return ret, nil
end

---@param bufnr (integer) Buffer handle, or 0 for current.
---@param params WorkspaceSymbolParams workspace symbol params: query string or symbol kind to filter
---@param handler? lsp.Handler See |lsp-handler|
---
---@return table<integer, integer> client_request_ids Map of client-id:request-id pairs
---for all successful requests.
---@return function _cancel_all_requests Function which can be used to
---cancel all the requests. You could instead
---iterate all clients and call their `cancel_request()` methods.
M.workspace_symbol_async = function(bufnr, params, handler)
	if not handler then
		handler = vim.lsp.handlers[ms.workspace_symbol]
	end
	---@type lsp.Handler
	local h = handler
	if params.kind then
		h = function(err, resp, context, config)
			if resp and not err then
				---@type lsp.WorkspaceSymbol[]
				local symbols = resp
				resp = filter_symbol(symbols, params.kind)
			end

			return handler(err, resp, context, config)
		end
	end
	return vim.lsp.buf_request(bufnr, ms.workspace_symbol, params, h)
end

function M._get_symbol_kind_name(symbol_kind)
	return lsp.protocol.SymbolKind[symbol_kind] or "Unknown"
end

--- Converts symbols to quickfix list items.
--- copy from `vim.lsp.util.symbols_to_items` with add symbol to the item
---@param symbols  lsp.DocumentSymbol[] | lsp.SymbolInformation[]
function M.symbols_to_items(symbols, bufnr)
	---@param _symbols  lsp.DocumentSymbol[] | lsp.SymbolInformation[]
	local function _symbols_to_items(_symbols, _items, _bufnr)
		for _, symbol in ipairs(_symbols) do
			if symbol.location then -- SymbolInformation type
				local range = symbol.location.range
				local kind = M._get_symbol_kind_name(symbol.kind)
				table.insert(_items, {
					filename = vim.uri_to_fname(symbol.location.uri),
					lnum = range.start.line + 1,
					col = range.start.character + 1,
					kind = kind,
					text = "[" .. kind .. "] " .. symbol.name,
					symbol = { containerName = symbol.containerName },
				})
			elseif symbol.selectionRange then -- DocumentSymbole type
				local kind = M._get_symbol_kind_name(symbol.kind)
				table.insert(_items, {
					-- bufnr = _bufnr,
					filename = api.nvim_buf_get_name(_bufnr),
					lnum = symbol.selectionRange.start.line + 1,
					col = symbol.selectionRange.start.character + 1,
					kind = kind,
					text = "[" .. kind .. "] " .. symbol.name,
					symbol = { containerName = symbol.containerName },
				})
				if symbol.children then
					for _, v in ipairs(_symbols_to_items(symbol.children, _items, _bufnr)) do
						for _, s in ipairs(v) do
							table.insert(_items, s)
						end
					end
				end
			end
		end
		return _items
	end
	return _symbols_to_items(symbols, {}, bufnr or 0)
end

return M
