local api = vim.api
local lsp = vim.lsp
local util = lsp.util
local ms = lsp.protocol.Methods

local M = {}

---@class lsp.server.opts
---@field handlers? table<string, fun(method: string, params: any): any>
---@field on_request? fun(method: string, params)
---@field on_notify? fun(method: string, params)
---@field capabilities? table

--- Create a in-process LSP server that can be used as `cmd` with |vim.lsp.start|
--- Example:
--- <pre>lua
--- vim.lsp.start({
---   name = "my-in-process-server",
---   cmd = vim.lsp.server({
---   handlers = {
---
---   }
---   })
--- })
---
--- @param opts nil|lsp.server.opts
function M.server(opts)
	opts = opts or {}
	local capabilities = opts.capabilities or {}
	local on_request = opts.on_request or function(_, _) end
	local on_notify = opts.on_notify or function(_, _) end
	local handlers = opts.handlers or {}

	return function(dispatchers)
		local closing = false
		local srv = {}
		local request_id = 0

		function srv.request(method, params, callback)
			pcall(on_request, method, params)
			local handler = handlers[method]
			if handler then
				local response, err = handler(method, params)
				callback(err, response)
			elseif method == "initialize" then
				callback(nil, {
					capabilities = capabilities,
				})
			elseif method == "shutdown" then
				callback(nil, nil)
			end
			request_id = request_id + 1
			return true, request_id
		end

		function srv.notify(method, params)
			pcall(on_notify, method, params)
			if method == "exit" then
				dispatchers.on_exit(0, 15)
			end
		end

		function srv.is_closing()
			return closing
		end

		function srv.terminate()
			closing = true
		end

		return srv
	end
end

---@param is_closer function (x,y) x is before y
local function move_to_highlight(is_closer)
	local win = api.nvim_get_current_win()
	local lnum, col = unpack(api.nvim_win_get_cursor(win))
	lnum = lnum - 1
	local cursor = {
		start = { line = lnum, character = col },
	}

	local params = util.make_position_params()
	local responses = lsp.buf_request_sync(0, ms.textDocument_documentHighlight, params)
	if not responses then
		return
	end
	local closest = nil
	for _, resp in pairs(responses) do
		local result = resp.result or {}
		for _, highlight in pairs(result) do
			local range = highlight.range
			local range_start = range.start
			local range_end = range["end"]
			local cursor_inside_range = (
				range_start.line <= lnum
				and range_end.line >= lnum
				and range_start.character < col
				and range_end.character > col
			)
			if
				not cursor_inside_range
				and is_closer(cursor, range)
				and (closest == nil or is_closer(range, closest))
			then
				closest = range
			end
		end
	end
	if closest then
		api.nvim_win_set_cursor(win, { closest.start.line + 1, closest.start.character })
	end
end

-- x is before y
local function is_before(x, y)
	if x.start.line < y.start.line then
		return true
	elseif x.start.line == y.start.line then
		return x.start.character < y.start.character
	else
		return false
	end
end

---@param direction "forward"|"backward" (string)
---@param opts any
local goto_highlight = function(direction, opts)
	local opts = opts or {}
	local responses = lsp.buf_request_sync(0, ms.textDocument_documentHighlight, util.make_position_params())
	if not responses then
		return
	end

	local highlights = responses[1].result or {}
	table.sort(highlights, function(a, b)
		return is_before(a.range, b.range)
	end)

	local win = api.nvim_get_current_win()
	local lnum, col = unpack(api.nvim_win_get_cursor(win))
	lnum = lnum - 1

	local cur_hl_idx = 0
	for idx, hl in ipairs(highlights) do
		local range_start = hl.range.start
		local range_end = hl.range["end"]

		local cursor_inside_range = (
			range_start.line <= lnum
			and range_end.line >= lnum
			and range_start.character <= col
			and range_end.character > col
		)

		if cursor_inside_range then
			cur_hl_idx = idx
			break
		end
	end

	local hls_len = #highlights
	if cur_hl_idx > 0 then
		local closest
		if direction == "forward" then
			local idx = cur_hl_idx % hls_len + 1
			closest = highlights[idx].range
		end
		if direction == "backward" then
			local idx = cur_hl_idx - 1
			if idx == 0 then
				idx = hls_len
			end
			closest = highlights[idx].range
		end
		api.nvim_win_set_cursor(win, { closest.start.line + 1, closest.start.character })
	end
end

M.document_highlight = {
	goto_next = function(opts)
		return goto_highlight("forward")
		-- return move_to_highlight(is_before)
	end,
	goto_prev = function(opts)
		return goto_highlight("backward")
		-- return move_to_highlight(function(x, y)
		-- 	return is_before(y, x)
		-- end)
	end,
}

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
