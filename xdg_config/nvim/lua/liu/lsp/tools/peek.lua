local M = {}

local sessions = {}

local open_previewwin = function(bufnr)
	vim.api.nvim_cmd({ cmd = "pbuffer", args = { tostring(bufnr) } }, {})

	local pvwinid
	for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.wo[winid].previewwindow then
			pvwinid = winid
			break
		end
	end
	assert(pvwinid, "pbuffer did not open a preview window")
	return pvwinid
end

local location_entry = function(loc)
	-- location may be LocationLink or Location
	local uri = loc.targetUri or loc.uri
	if uri == nil then
		return
	end
	local bufnr = vim.uri_to_bufnr(uri)
	local range = loc.targetRange or loc.range
	local pos = { range.start["line"] + 1, range.start["character"] }
	local end_pos = { range["end"]["line"] + 1, range["end"]["character"] }
	local filename = vim.fn.fnamemodify(vim.uri_to_fname(uri), ":t")
	return {
		bufnr = bufnr,
		pos = pos,
		end_pos = end_pos,
		label = ("%s:%d"):format(filename, pos[1]),
	}
end

local winbar_for_session = function(session)
	local labels = vim.iter(session.entries)
		:map(function(entry)
			return entry.label
		end)
		:totable()
	local max_width = math.max(20, vim.api.nvim_win_get_width(session.winid) - 4)
	local start_index, end_index = session.index, session.index

	local display_width = function(first, last)
		local width = first > 1 and 4 or 0
		for index = first, last do
			width = width + vim.fn.strdisplaywidth(labels[index])
			if index < last then
				width = width + 3
			end
		end
		return width + (last < #labels and 4 or 0)
	end

	while true do
		local changed = false
		if start_index > 1 and display_width(start_index - 1, end_index) <= max_width then
			start_index = start_index - 1
			changed = true
		end
		if end_index < #labels and display_width(start_index, end_index + 1) <= max_width then
			end_index = end_index + 1
			changed = true
		end
		if not changed then
			break
		end
	end

	local parts = { "%#WinBar# " }
	if start_index > 1 then
		table.insert(parts, "… │ ")
	end
	for index = start_index, end_index do
		if index > start_index then
			table.insert(parts, " │ ")
		end
		local label = labels[index]:gsub("%%", "%%%%")
		if index == session.index then
			table.insert(parts, "%#PmenuSel# " .. label .. " %#WinBar#")
		else
			table.insert(parts, label)
		end
	end
	if end_index < #labels then
		table.insert(parts, " │ …")
	end
	return table.concat(parts)
end

local show_location = function(session)
	if not vim.api.nvim_win_is_valid(session.winid) then
		return
	end

	local entry = session.entries[session.index]
	if not vim.api.nvim_buf_is_loaded(entry.bufnr) then
		vim.fn.bufload(entry.bufnr)
	end
	if session.match_id then
		pcall(vim.fn.matchdelete, session.match_id, session.winid)
		session.match_id = nil
	end

	vim.api.nvim_win_set_buf(session.winid, entry.bufnr)
	vim.api.nvim_win_set_cursor(session.winid, entry.pos)
	vim.wo[session.winid].winbar = #session.entries > 1 and winbar_for_session(session) or ""
	if vim.api.nvim_win_get_config(session.winid).relative ~= "" then
		vim.api.nvim_win_set_config(session.winid, {
			footer = (" %s %d / %d "):format(session.title, session.index, #session.entries),
			footer_pos = "right",
		})
	end

	vim.api.nvim_win_call(session.winid, function()
		vim.cmd.normal("zz")
		local length = math.max(1, entry.end_pos[2] - entry.pos[2])
		local m = vim.fn.matchaddpos("Cursor", { { entry.pos[1], entry.pos[2] + 1, length } })
		session.match_id = m
		local timer = vim.uv.new_timer()
		timer:start(1000, 0, function()
			vim.schedule(function()
				if vim.api.nvim_win_is_valid(session.winid) then
					pcall(vim.fn.matchdelete, m, session.winid)
				end
				if session.match_id == m then
					session.match_id = nil
				end
			end)
			timer:close()
		end)
	end)
end

local preview_locations = function(entries, title, focus, source_bufnr)
	local pvwinid = open_previewwin(entries[1].bufnr)
	local previous_session = sessions[pvwinid]
	if previous_session and previous_session.match_id then
		pcall(vim.fn.matchdelete, previous_session.match_id, pvwinid)
	end
	local session = {
		entries = entries,
		index = 1,
		title = title,
		winid = pvwinid,
	}
	sessions[pvwinid] = session
	show_location(session)

	if focus then
		vim.api.nvim_set_current_win(pvwinid)
	else
		vim.api.nvim_create_autocmd("CursorMoved", {
			once = true,
			buffer = source_bufnr,
			callback = function()
				if sessions[pvwinid] == session and vim.api.nvim_win_is_valid(pvwinid) then
					vim.api.nvim_win_close(pvwinid, true)
				end
			end,
		})
	end

	vim.api.nvim_create_autocmd("WinClosed", {
		once = true,
		pattern = tostring(pvwinid),
		callback = function()
			if sessions[pvwinid] == session then
				sessions[pvwinid] = nil
			end
		end,
	})
end

local preview_location_callback = function(title, focus, source_bufnr)
	return function(err, res, _, cfg)
		if err then
			vim.notify(("Error running LSP query '%s'"):format(cfg.method), vim.log.levels.ERROR)
			return nil
		end
		if res == nil or vim.tbl_isempty(res) then
			vim.notify("Unable to find code location.", vim.log.levels.WARN)
			return nil
		end
		local locations = vim.islist(res) and res or { res }
		local entries = {}
		for _, location in ipairs(locations) do
			local entry = location_entry(location)
			if entry then
				table.insert(entries, entry)
			end
		end
		if vim.tbl_isempty(entries) then
			vim.notify("Unable to find code location.", vim.log.levels.WARN)
			return nil
		end
		preview_locations(entries, title, focus, source_bufnr)
	end
end

local change_location = function(offset)
	for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local session = sessions[winid]
		if session then
			session.index = (session.index - 1 + offset) % #session.entries + 1
			show_location(session)
			return
		end
	end
	vim.notify("No active peek preview.", vim.log.levels.WARN)
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

local methods = {
	def = {
		method = "textDocument/definition",
		title = "Definition",
	},
	impl = {
		method = "textDocument/implementation",
		title = "Implementation",
	},
	ref = {
		extra = { context = { includeDeclaration = true } },
		method = "textDocument/references",
		title = "References",
	},
}

function M.peek(kind, focus)
	kind = kind or "ref"
	local request = methods[kind]
	if not request then
		error(("Unknown peek method: %s"):format(kind))
	end
	local bufnr = vim.api.nvim_get_current_buf()
	local params = client_position_params(nil, request.extra)
	local callback = preview_location_callback(request.title, focus, bufnr)
	return vim.lsp.buf_request(bufnr, request.method, params, callback)
end

function M.peek_definition(focus)
	return M.peek("def", focus)
end

function M.peek_implementation(focus)
	return M.peek("impl", focus)
end

function M.peek_references(focus)
	return M.peek("ref", focus)
end

M.on_attach = function(client, buf)
	vim.keymap.set("n", "grp", M.peek_definition, { buffer = buf })

	vim.api.nvim_buf_create_user_command(buf, "Peek", function(opts)
		local arg = opts.args or "def"
		local offset = tonumber(arg)
		if offset then
			if offset % 1 ~= 0 then
				error("Peek offset must be an integer")
			end
			change_location(offset)
			return
		end
		M.peek(arg, opts.bang)
	end, {
		nargs = "?",
		bang = true,
		complete = function()
			return { "ref", "def", "impl", "+1", "-1" }
		end,
	})
end

return M
