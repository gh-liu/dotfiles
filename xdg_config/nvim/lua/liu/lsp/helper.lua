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

return M
