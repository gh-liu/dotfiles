local M = {}

vim.o.previewpopup = "height:20,width:80"

local open_previewwin = function(bufnr, pos)
	vim.api.nvim_cmd({ cmd = "pbuffer", args = { tostring(bufnr) } }, {})

	local pvwinid
	for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.wo[winid].previewwindow then
			pvwinid = winid
			break
		end
	end
	assert(pvwinid, "pbuffer did not open a preview window")

	vim.api.nvim_win_set_cursor(pvwinid, pos)
	vim.api.nvim_win_call(pvwinid, function()
		vim.cmd.normal("zz")
	end)
	return pvwinid
end

local preview_location = function(loc, focus, source_bufnr)
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
				if vim.api.nvim_win_is_valid(pvwinid) then
					pcall(vim.fn.matchdelete, m, pvwinid)
				end
			end)
			timer:close()
		end)
	end)
	if focus then
		vim.api.nvim_set_current_win(pvwinid)
	else
		vim.api.nvim_create_autocmd("CursorMoved", {
			once = true,
			buffer = source_bufnr,
			callback = function()
				if vim.api.nvim_win_is_valid(pvwinid) then
					vim.api.nvim_win_close(pvwinid, true)
				end
			end,
		})
	end
end

local preview_location_callback = function(focus, source_bufnr)
	return function(err, res, _, cfg)
		if err then
			vim.notify(("Error running LSP query '%s'"):format(cfg.method), vim.log.levels.ERROR)
			return nil
		end
		if res == nil or vim.tbl_isempty(res) then
			vim.notify("Unable to find code location.", vim.log.levels.WARN)
			return nil
		end
		if vim.islist(res) then
			preview_location(res[1], focus, source_bufnr)
		else
			preview_location(res, focus, source_bufnr)
		end
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

function M.peek_definition(focus)
	local bufnr = vim.api.nvim_get_current_buf()
	local param = client_position_params()
	return vim.lsp.buf_request(bufnr, "textDocument/definition", param, preview_location_callback(focus, bufnr))
end

M.on_attach = function(client, buf)
	vim.keymap.set("n", "grp", M.peek_definition, { buffer = buf })

	vim.api.nvim_buf_create_user_command(buf, "Peek", function(opts)
		M.peek_definition(opts.bang)
	end, { nargs = 0, bang = true })
end

return M
