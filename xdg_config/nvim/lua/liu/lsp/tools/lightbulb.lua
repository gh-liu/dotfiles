--- VSCode-like lightbulb.
--- Implementation inspired from https://github.com/nvimdev/lspsaga.nvim/blob/main/lua/lspsaga/codeaction/lightbulb.lua

local M = {}

local api = vim.api
local lsp = vim.lsp
local utils = require("liu.utils")

local lb_icon = "💡"
local lb_icon_priority = 20
local lb_icon_hl = "DiagnosticSignHint"
local lb_name = "liu/lsp_lightbulb"
local lb_namespace = api.nvim_create_namespace(lb_name)
local code_action_method = lsp.protocol.Methods.textDocument_codeAction

local debounce_ms = 500

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
---@param line integer # 0-based line
---@param col integer # 0-based column
---@return vim.Diagnostic[]
local function filter_diagnostic_at_cursor(diagnostics, line, col)
	return vim.iter(diagnostics)
		:map(function(diag)
			local end_lnum = diag.end_lnum or diag.lnum
			local end_col = diag.end_col or diag.col
			if diag.lnum <= line and line <= end_lnum then
				if diag.col <= col and col <= end_col then
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
	local line, col = unpack(cursor)
	line = line - 1

	local params_with_diag = function(client, buf)
		local position = vim.pos.cursor(buf, api.nvim_win_get_cursor(win)):to_lsp(client.offset_encoding)
		local params = {
			textDocument = vim.lsp.util.make_text_document_params(buf),
			range = { start = position, ["end"] = position },
		}

		local diagnostics = {}
		for _, ns in pairs(vim.diagnostic.get_namespaces()) do
			if ns.name and ns.name:find("nvim.lsp." .. client.name .. "." .. client.id, 1, true) then
				vim.list_extend(diagnostics, vim.diagnostic.get(buf, { namespace = ns.id, lnum = line }))
			end
		end
		diagnostics = filter_diagnostic_at_cursor(diagnostics, line, col)

		local extra_param = {
			context = {
				diagnostics = vim.tbl_map(function(diagnostic)
					return diagnostic.user_data and diagnostic.user_data.lsp or diagnostic
				end, diagnostics),
				triggerKind = lsp.protocol.CodeActionTriggerKind.Automatic,
			},
		}
		return vim.tbl_extend("force", params, extra_param)
	end

	local has_actions = false
	lsp.buf_request(bufnr, code_action_method, params_with_diag, function(_, res, _)
		if api.nvim_get_current_buf() ~= bufnr then
			return
		end
		if res and #res > 0 then
			has_actions = true
			update_extmark(bufnr, line)
		elseif not has_actions then
			update_extmark(bufnr)
		end
	end)
end

local update = (function()
	---@param bufnr integer
	local debounced_render = utils.debounce(debounce_ms, function(bufnr)
		if api.nvim_buf_is_valid(bufnr) and api.nvim_get_current_buf() == bufnr then
			render(bufnr)
		end
	end)

	return function(bufnr)
		update_extmark(latest_updated_bufnr)
		debounced_render(bufnr)
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
