local M = {}

local open_previewwin = function(bufnr, pos)
	local pvwid
	local winids = vim.api.nvim_tabpage_list_wins(0)
	for _, winid in ipairs(winids) do
		if vim.wo[winid].previewwindow then
			pvwid = winid
		end
	end
	if not pvwid then
		local winid = vim.api.nvim_open_win(bufnr, false, {
			split = "above", ---@type "left"| "right"| "above"| "below"
			height = vim.o.previewheight,
		})
		vim.wo[winid].previewwindow = true
		pvwid = winid
	else
		vim.api.nvim_win_set_buf(pvwid, bufnr)
	end
	vim.api.nvim_win_set_cursor(pvwid, pos)
	vim.api.nvim_win_call(pvwid, function()
		vim.cmd.normal("zz")
	end)
	return pvwid
end

local preview_location = function(loc, _, _)
	-- location may be LocationLink or Location
	local uri = loc.targetUri or loc.uri
	if uri == nil then
		return
	end
	local bufnr = vim.uri_to_bufnr(uri)
	if not vim.api.nvim_buf_is_loaded(bufnr) then
		vim.fn.bufload(bufnr)
	end
	local range = loc.targetRange or loc.range
	local pos = { range.start["line"] + 1, range.start["character"] }
	local end_pos = { range["end"]["line"] + 1, range["end"]["character"] }
	local pvwinid = open_previewwin(bufnr, pos)
	vim.api.nvim_win_call(pvwinid, function()
		local m = vim.fn.matchaddpos("Cursor", { { pos[1], pos[2] + 1, end_pos[2] - pos[2] } })
		local timer = vim.uv.new_timer()
		timer:start(1000, 0, function()
			vim.schedule(function()
				vim.fn.matchdelete(m, pvwinid)
			end)
			timer:close()
		end)
	end)
end

local preview_location_callback = function(err, res, ctx, cfg)
	if err then
		vim.notify(("Error running LSP query '%s'"):format(cfg.method), vim.log.levels.ERROR)
		return nil
	end
	if res == nil or vim.tbl_isempty(res) then
		vim.notify("Unable to find code location.", vim.log.levels.WARN)
		return nil
	end
	if vim.islist(res) then
		preview_location(res[1], ctx, cfg)
	else
		preview_location(res, ctx, cfg)
	end
end

---@param win number? Window handler
---@param extra table? Extra fields in params
---@return table|(fun(client: vim.lsp.Client, buf: integer): table) parmas to send to the server
local function client_position_params(win, extra)
	win = win or vim.api.nvim_get_current_win()
	return function(client, buf)
		local params = vim.lsp.util.make_position_params(win, client.offset_encoding)
		if extra then
			params = vim.tbl_extend("force", params, extra)
		end
		return params
	end
end

function M.peek_definition()
	local param = client_position_params()
	return vim.lsp.buf_request(0, "textDocument/definition", param, preview_location_callback)
end

M.on_attach = function(client, buf)
	vim.keymap.set("n", "grp", M.peek_definition, { buffer = buf })

	vim.api.nvim_buf_create_user_command(buf, "Peek", function()
		M.peek_definition()
	end, { nargs = 0 })
end

return M
