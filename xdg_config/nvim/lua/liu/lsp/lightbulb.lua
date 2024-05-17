--- VSCode-like lightbulb.
--- Implementation inspired from https://github.com/nvimdev/lspsaga.nvim/blob/main/lua/lspsaga/codeaction/lightbulb.lua

local api = vim.api
local lsp = vim.lsp

local lb_icon = "💡"
local lb_icon_priority = 20
-- local lb_icon_hl = "DiagnosticSignHint"
local lb_name = "liu/lsp_lightbulb"
local lb_namespace = api.nvim_create_namespace(lb_name)
local lb_group = api.nvim_create_augroup(lb_name, {})
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

	pcall(api.nvim_buf_set_extmark, bufnr, lb_namespace, line, -1, { sign_text = lb_icon, priority = lb_icon_priority })

	latest_updated_bufnr = bufnr
end

--- Queries the LSP servers for code actions and updates the lightbulb
--- accordingly.
---@param bufnr number
local function render(bufnr)
	local line = api.nvim_win_get_cursor(0)[1] - 1
	local diagnostics = lsp.diagnostic.get_line_diagnostics(bufnr, line)

	local params = lsp.util.make_range_params()
	params.context = {
		diagnostics = diagnostics,
		triggerKind = lsp.protocol.CodeActionTriggerKind.Automatic,
	}

	lsp.buf_request(bufnr, code_action_method, params, function(_, res, _)
		if api.nvim_get_current_buf() ~= bufnr then
			return
		end

		update_extmark(bufnr, (res and #res > 0 and line) or nil)
	end)
end

---@param bufnr number
local update = (function()
	local timer = vim.uv.new_timer()
	---@param bufnr number
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

local on_attach = function(client, bufnr)
	if not client or not client.supports_method(code_action_method) then
		return true
	end

	local buf_group_name = buf_group_name_fn(bufnr)
	if pcall(api.nvim_get_autocmds, { group = buf_group_name, buffer = bufnr }) then
		return
	end

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
			update_extmark(bufnr, nil)
		end,
	})
end

local on_detach = function(bufnr)
	local buf_group_name = buf_group_name_fn(bufnr)
	pcall(api.nvim_del_augroup_by_name, buf_group_name)
end

api.nvim_create_autocmd("LspAttach", {
	desc = "Configure code action lightbulb",
	group = lb_group,
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		on_attach(client, args.buf)
	end,
})

api.nvim_create_autocmd("LspDetach", {
	desc = "Detach code action lightbulb",
	group = lb_group,
	callback = function(args)
		on_detach(args.buf)
	end,
})
