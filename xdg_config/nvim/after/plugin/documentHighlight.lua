local config = {
	debounce = 200,
	jumplist = true,
	foldopen = true,
	notify_jump = true,
}

local M = {}

M.is_enabled = function(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = buf })
	clients = vim.tbl_filter(function(client)
		return client:supports_method("textDocument/documentHighlight", buf)
	end, clients)
	return #clients > 0
end

M.clear = function()
	vim.lsp.buf.clear_references()
end

local timer = (vim.uv or vim.loop).new_timer()
M.update = function()
	local buf = vim.api.nvim_get_current_buf()
	timer:start(config.debounce, 0, function()
		vim.schedule(function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_call(buf, function()
					if not M.is_enabled() then
						return
					end
					vim.lsp.buf.document_highlight()
					M.clear()
				end)
			end
		end)
	end)
end

---@alias LspWord {from:{[1]:number, [2]:number}, to:{[1]:number, [2]:number}} 1-0 indexed

local ns = vim.api.nvim_create_namespace("vim_lsp_references")
local ns2 = vim.api.nvim_create_namespace("nvim.lsp.references")

---@private
---@return LspWord[] words, number? current
M.get = function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local current, ret = nil, {} ---@type number?, LspWord[]
	local extmarks = {} ---@type vim.api.keyset.get_extmark_item[]
	vim.list_extend(extmarks, vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true }))
	vim.list_extend(extmarks, vim.api.nvim_buf_get_extmarks(0, ns2, 0, -1, { details = true }))
	for _, extmark in ipairs(extmarks) do
		local w = {
			from = { extmark[2] + 1, extmark[3] },
			to = { extmark[4].end_row + 1, extmark[4].end_col },
		}
		ret[#ret + 1] = w
		if cursor[1] >= w.from[1] and cursor[1] <= w.to[1] and cursor[2] >= w.from[2] and cursor[2] <= w.to[2] then
			current = #ret
		end
	end
	return ret, current
end
---@param count? number
---@param cycle? boolean
function M.jump(count, cycle)
	count = count or 1
	local words, idx = M.get()
	if not idx then
		return
	end
	idx = idx + count
	if cycle then
		idx = (idx - 1) % #words + 1
	end
	local target = words[idx]
	if target then
		if config.jumplist then
			vim.cmd.normal({ "m`", bang = true })
		end
		vim.api.nvim_win_set_cursor(0, target.from)
		if config.notify_jump then
			vim.notify(("Reference [%d/%d]"):format(idx, #words), vim.log.levels.INFO)
		end
		if config.foldopen then
			vim.cmd.normal({ "zv", bang = true })
		end
	end
end

local group = vim.api.nvim_create_augroup("liu/lsp_doc_hi", { clear = true })
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "ModeChanged" }, {
	group = group,
	callback = function()
		if not M.is_enabled() then
			M.clear()
			return
		end
		if not ({ M.get() })[2] then
			M.update()
		end
	end,
})

vim.keymap.set({ "n" }, "]w", function()
	M.jump(vim.v.count1, true)
end, {})
vim.keymap.set({ "n" }, "[w", function()
	M.jump(-vim.v.count1, true)
end, {})
