--- VSCode-like lightbulb.
--- Implementation inspired from https://github.com/nvimdev/lspsaga.nvim/blob/main/lua/lspsaga/codeaction/lightbulb.lua

local M = {}

local api = vim.api
local lsp = vim.lsp

local lb_icon = "💡"
local lb_icon_priority = 20
local lb_icon_hl = "DiagnosticSignHint"
local lb_name = "liu/lsp_lightbulb"
local lb_namespace = api.nvim_create_namespace(lb_name)
local code_action_method = lsp.protocol.Methods.textDocument_codeAction

local debounce = 200

local latest_updated_bufnr = nil

--- Updates the lightbulb.
---@param bufnr number? buffer number
---@param line number? clear the lightbulb of the buffer if the line is nil.
local function update_extmark(bufnr, line)
	if not bufnr or not api.nvim_buf_is_valid(bufnr) then
		return
	end

	api.nvim_buf_clear_namespace(bufnr, lb_namespace, 0, -1)

	if not line then
		return
	end

	pcall(vim.api.nvim_buf_set_extmark, bufnr, lb_namespace, line, -1, {
		-- sign
		sign_text = lb_icon,
		priority = lb_icon_priority,
		sign_hl_group = lb_icon_hl,
		-- end of line
		-- virt_text = { {
		-- 	" " .. lb_icon,
		-- 	lb_icon_hl,
		-- } },
		-- hl_mode = "combine",
	})

	latest_updated_bufnr = bufnr
end

---@param diagnostics vim.Diagnostic[]
---@param cursor integer[] # (row, col) tuple
---@return vim.Diagnostic[]
local function filter_diagnostic_at_cursor(diagnostics, cursor)
	local line, col = unpack(cursor)
	return vim.iter(diagnostics)
		:map(function(diag)
			if diag.lnum <= line and line <= diag.end_lnum then
				if diag.col <= col and col <= diag.end_col then
					return diag
				end
			end
		end)
		:totable()
end

--- Queries the LSP servers for code actions and updates the lightbulb
--- accordingly.
---@param bufnr integer
local function render(bufnr)
	local win = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(win)
	local line, _ = unpack(cursor)
	line = line - 1

	local params_with_diag = function(client, buf)
		local params = vim.lsp.util.make_range_params(win, client.offset_encoding)

		local diagnostics = {}
		local ns_push = lsp.diagnostic.get_namespace(client.id, false)
		local ns_pull = lsp.diagnostic.get_namespace(client.id, true)
		vim.list_extend(diagnostics, vim.diagnostic.get(buf, { namespace = ns_pull, lnum = line }))
		vim.list_extend(diagnostics, vim.diagnostic.get(buf, { namespace = ns_push, lnum = line }))
		diagnostics = filter_diagnostic_at_cursor(diagnostics, cursor)

		local extra_param = {
			context = {
				diagnostics = vim.lsp.diagnostic.from(diagnostics),
				triggerKind = lsp.protocol.CodeActionTriggerKind.Automatic,
			},
		}
		return vim.tbl_extend("force", params, extra_param)
	end

	lsp.buf_request(bufnr, code_action_method, params_with_diag, function(_, res, _)
		if api.nvim_get_current_buf() ~= bufnr then
			return
		end
		update_extmark(bufnr, (res and #res > 0 and line) or nil)
	end)
end

local update = (function()
	local timer = vim.uv.new_timer()

	---@param bufnr integer
	return function(bufnr)
		update_extmark(latest_updated_bufnr)

		timer:start(debounce, 0, function()
			timer:stop()
			vim.schedule(function()
				if api.nvim_buf_is_valid(bufnr) and api.nvim_get_current_buf() == bufnr then
					render(bufnr)
				end
			end)
		end)
	end
end)()

local buf_group_name_fn = function(bufnr)
	return lb_name .. tostring(bufnr)
end

---@param client vim.lsp.Client
---@param bufnr integer
M.on_attach = function(client, bufnr)
	if not client or not client:supports_method(code_action_method) then
		return true
	end

	local buf_group_name = buf_group_name_fn(bufnr)
	local lb_buf_group = api.nvim_create_augroup(buf_group_name, { clear = true })
	api.nvim_create_autocmd({ "CursorHold" }, {
		group = lb_buf_group,
		desc = "Update lightbulb when holding the cursor(only execute once when attach)",
		buffer = bufnr,
		callback = function()
			update(bufnr)
		end,
		once = true,
	})

	api.nvim_create_autocmd({ "CursorMoved" }, {
		group = lb_buf_group,
		desc = "Update lightbulb when moving the cursor in normal/visual mode",
		buffer = bufnr,
		callback = function()
			update(bufnr)
		end,
	})

	api.nvim_create_autocmd({ "InsertEnter", "BufLeave" }, {
		group = lb_buf_group,
		desc = "Update lightbulb when entering insert mode or leaving the buffer",
		buffer = bufnr,
		callback = function()
			update_extmark(bufnr)
		end,
	})
end

api.nvim_create_autocmd("LspDetach", {
	desc = "Detach code action lightbulb",
	callback = function(args)
		local buf = args.buf
		pcall(api.nvim_del_augroup_by_name, buf_group_name_fn(buf))
	end,
})

return M
