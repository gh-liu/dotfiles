local config = {
	debounce = 200,
	jumplist = true,
	foldopen = true,
	notify_jump = true,
}

local M = {}
local utils = require("liu.utils")

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

local debounced_update = utils.debounce(config.debounce, function()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_call(buf, function()
		if not M.is_enabled() then
			return
		end
		vim.lsp.buf.document_highlight()
		M.clear()
	end)
end)

M.update = function()
	debounced_update()
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

return {
	on_attach = function(client, buf)
		local group = vim.api.nvim_create_augroup("liu/lsp_doc_hi" .. buf, { clear = true })

		-- CmdAtom is global (its pattern is the atom type), so filter by buffer.
		-- Replaces the CursorMoved firehose: fires only for user actions, and
		-- collapses a Visual sequence / Insert session into one atom.
		-- Programmatic moves (`:normal`, API) never fire; intra-insert cursor
		-- moves are part of the insert atom, so they update once on session end.
		vim.api.nvim_create_autocmd("CmdAtom", {
			group = group,
			callback = function(ev)
				if ev.buf ~= buf then
					return
				end
				-- Keep buffer-local semantics: CmdAtom is global and deferred, so
				-- only act when `buf` is still the current buffer (M.get()/update()
				-- read the current window's cursor).
				if vim.api.nvim_get_current_buf() ~= buf then
					return
				end
				local type = ev.data.type
				if
					type ~= "motion"
					and type ~= "jump"
					and type ~= "visual"
					and type ~= "insert"
				then
					return
				end

				if not M.is_enabled() then
					M.clear()
					return
				end
				if not ({ M.get() })[2] then
					M.update()
				end
			end,
		})

		-- Intra-insert moves emit no CmdAtom until the insert session ends, so
		-- clear highlights as soon as Insert mode starts.
		vim.api.nvim_create_autocmd("ModeChanged", {
			group = group,
			buffer = buf,
			callback = function()
				local mode = vim.api.nvim_get_mode().mode
				if mode:sub(1, 1) == "i" or mode:sub(1, 1) == "R" then
					M.clear()
				end
			end,
		})

		-- CmdAtom autocmds are global; drop them with the augroup on detach.
		vim.api.nvim_create_autocmd("LspDetach", {
			group = group,
			callback = function(args)
				if args.buf == buf then
					pcall(vim.api.nvim_del_augroup_by_name, "liu/lsp_doc_hi" .. buf)
				end
			end,
		})

		vim.keymap.set({ "n" }, "]w", function()
			M.jump(vim.v.count1, true)
		end, { buffer = buf })
		vim.keymap.set({ "n" }, "[w", function()
			M.jump(-vim.v.count1, true)
		end, { buffer = buf })
	end,
}
