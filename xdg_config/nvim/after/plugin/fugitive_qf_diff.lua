local auto_diff_enabled = 0

local function debounce(ms, fn)
	local timer = vim.uv.new_timer()
	return function(...)
		local argv = { ... }
		timer:start(ms, 0, function()
			timer:stop()
			vim.schedule_wrap(fn)(unpack(argv))
		end)
	end
end

local current_qfid_equal = function(qfid)
	local cur_qfid = vim.fn.getqflist({ id = 0 }).id
	return cur_qfid == qfid
end

local is_qfwin_opened = function()
	return vim.fn.getqflist({ winid = 0 }).winid > 0
end

local is_current_diffbuf_showed = function(buf)
	return vim.iter(vim.api.nvim_list_wins())
		:map(function(winid)
			return vim.api.nvim_win_get_buf(winid)
		end)
		:any(function(bufnr)
			return vim.b[buf].diff_buf == bufnr
		end)
end

local do_diff = function(buf)
	if is_current_diffbuf_showed(buf) then
		return
	end

	local fname = vim.b[buf].diff_filename
	if fname then
		vim.cmd("leftabove vert diffsplit " .. fname)
		vim.cmd("wincmd p")
	end
end

local debounce_do_diff = debounce(200, function()
	local cur_buf = vim.api.nvim_get_current_buf()
	if vim.b[cur_buf].diff_buf then
		do_diff(cur_buf)
	end
end)

local unload_diffbuf = function(bufnr)
	local diff_buf = vim.b[bufnr].diff_buf
	if diff_buf and vim.api.nvim_buf_is_valid(diff_buf) then
		if vim.fn.bufloaded(diff_buf) == 1 then
			vim.cmd(diff_buf .. [[bunload!]])
			-- vim.api.nvim_buf_delete(diff_buf, { unload = true })
		end
	end
end

-- https://github.com/tpope/vim-fugitive/issues/132
-- apply event: https://github.com/tpope/vim-fugitive/blob/593f831d6f6d779cbabb70a4d1e6b1b1936a88af/autoload/fugitive.vim#L1575
vim.api.nvim_create_autocmd({ "QuickFixCmdPost" }, {
	pattern = "cfugitive-difftool",
	callback = function()
		local qflist = vim.fn.getqflist({ items = 0, id = 0, context = 0, size = 0 })
		if qflist.size == 0 then
			return
		end
		local items = qflist.items
		local module = items[1].module
		-- https://github.com/tpope/vim-fugitive/blob/593f831d6f6d779cbabb70a4d1e6b1b1936a88af/autoload/fugitive.vim#L5645
		if vim.startswith(module, ":2:") or vim.startswith(module, ":3:") then
			return
		end

		local qfid = qflist.id

		local set_buf_stuff = function(buf)
			local qf = vim.fn.getqflist({ context = 0, idx = 0, id = qfid })
			local diffs = qf.context.items[qf.idx].diff
			if not diffs or #diffs == 0 then
				return
			end
			local diff = diffs[1]
			vim.b[buf].diff_filename = diff.filename
			vim.b[buf].diff_buf = vim.fn.bufnr(diff.filename, true)

			vim.keymap.set("n", "\\d", "<cmd>GDiffWithCtx<cr>", { buffer = buf })
			vim.keymap.set("n", "\\D", "<cmd>GDiffWithCtx!<cr>", { buffer = buf })
			vim.api.nvim_buf_create_user_command(buf, "GDiffWithCtx", function(args)
				if args.bang and auto_diff_enabled == 1 then
					auto_diff_enabled = 0
					vim.api.nvim_exec_autocmds("BufDelete", {
						modeline = false,
						buffer = buf,
					})
					return
				end
				if args.bang then
					auto_diff_enabled = 1
				end
				do_diff(buf)
			end, { bang = true, nargs = 0 })
		end

		local g = vim.api.nvim_create_augroup(string.format("fugitive/qfid:%d/diff", qfid), { clear = true })
		for _, item in ipairs(items) do
			local buf = item.bufnr
			vim.api.nvim_create_autocmd("BufReadPost", {
				buffer = buf,
				group = g,
				callback = function()
					set_buf_stuff(buf)
					if auto_diff_enabled == 1 and is_qfwin_opened() and current_qfid_equal(qfid) then
						debounce_do_diff()
					end
				end,
			})
			vim.api.nvim_create_autocmd("BufDelete", {
				buffer = buf,
				group = g,
				callback = function(ev)
					unload_diffbuf(ev.buf)
				end,
			})
		end
	end,
})
