vim.g.DiffEnabled = 0
-- https://github.com/tpope/vim-fugitive/issues/132
-- apply event: https://github.com/tpope/vim-fugitive/blob/593f831d6f6d779cbabb70a4d1e6b1b1936a88af/autoload/fugitive.vim#L1575
vim.api.nvim_create_autocmd({ "QuickFixCmdPost" }, {
	pattern = "cfugitive-difftool",
	callback = function()
		local qflist = vim.fn.getqflist({ items = 0, id = 0, context = 0, idx = 0 })
		local qfid = qflist.id
		local items = qflist.items

		if vim.g.DiffEnabled == 1 and #items > 0 then
			local module = items[1].module
			-- https://github.com/tpope/vim-fugitive/blob/593f831d6f6d779cbabb70a4d1e6b1b1936a88af/autoload/fugitive.vim#L5645
			if vim.startswith(module, ":2:") or vim.startswith(module, ":3:") then
				return
			end
		end
		local do_diff = function(buf)
			local cur_qfid = vim.fn.getqflist({ id = 0 }).id
			if cur_qfid ~= qfid then
				return
			end

			local fname = vim.b[buf].diff_filename
			if fname then
				vim.cmd("leftabove vert diffsplit " .. fname)
				vim.cmd("wincmd p")
			end
		end

		local set_buf_stuff = function(buf, qf)
			qf = qf or vim.fn.getqflist({ context = 0, idx = 0, id = qfid })
			local diffs = qf.context.items[qf.idx].diff
			if not diffs or #diffs == 0 then
				return
			end
			local diff = diffs[1]
			vim.b[buf].diff_filename = diff.filename
			vim.b[buf].diff_buf = vim.fn.bufnr(diff.filename, true)

			vim.keymap.set("n", "\\d", function()
				do_diff(buf)
			end, { buffer = buf })
			vim.keymap.set("n", "\\D", function()
				do_diff(buf)
				vim.g.DiffEnabled = 1
			end, { buffer = buf })
			vim.api.nvim_buf_create_user_command(buf, "GDiffWithCtx", function(args)
				if args.bang and vim.g.DiffEnabled == 1 then
					vim.g.DiffEnabled = 0
					vim.api.nvim_exec_autocmds("BufDelete", {
						modeline = false,
						buffer = buf,
					})
					return
				end
				if args.bang then
					vim.g.DiffEnabled = 1
				end
				do_diff(buf)
			end, { bang = true, nargs = 0 })
		end

		local bufs = {}
		for _, item in ipairs(items) do
			local buf = item.bufnr
			bufs[buf] = true
			if vim.fn.bufloaded(buf) == 1 then
				set_buf_stuff(buf, qflist)
			end
		end

		local g = vim.api.nvim_create_augroup(string.format("fugitive/qfid:%d/diff", qfid), { clear = true })
		-- https://github.com/tpope/vim-fugitive/blob/593f831d6f6d779cbabb70a4d1e6b1b1936a88af/autoload/fugitive.vim#L3072
		-- seems all fugitive files be set option `bufhidden=delete`, so toggle between qf items will cause the buffer be deleted
		vim.api.nvim_create_autocmd("BufAdd", {
			group = g,
			callback = function(args)
				local buf = args.buf
				if bufs[buf] then
					set_buf_stuff(buf)
					if vim.g.DiffEnabled == 1 then
						vim.schedule(function()
							local cur_buf = vim.api.nvim_get_current_buf()
							if cur_buf == buf then
								do_diff(buf)
							end
						end)
					end
				end
			end,
		})

		vim.api.nvim_create_autocmd("BufDelete", {
			group = g,
			callback = function(args)
				local buf = args.buf
				if bufs[buf] then
					local diff_buf = vim.b[buf].diff_buf
					if diff_buf and vim.api.nvim_buf_is_valid(diff_buf) then
						vim.api.nvim_buf_delete(diff_buf, { force = true })
					end
				end
			end,
		})
	end,
})
