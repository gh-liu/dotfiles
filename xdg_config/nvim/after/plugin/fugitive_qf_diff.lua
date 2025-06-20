vim.g.DiffEnabled = 1
-- https://github.com/tpope/vim-fugitive/issues/132
vim.api.nvim_create_autocmd({ "QuickFixCmdPost" }, {
	pattern = "cfugitive-difftool",
	callback = function()
		local qflist = vim.fn.getqflist({ items = 0, qfbufnr = 0, context = 0, idx = 0 })
		local qfbufnr = qflist.qfbufnr
		local items = qflist.items

		local set_buf_stuff = function(buf, qf)
			qf = qf or vim.fn.getqflist({ context = 0, idx = 0 })
			local diffs = qf.context.items[qf.idx].diff
			local diff = diffs[1]
			vim.b[buf].diff_filename = diff.filename
			vim.b[buf].diff_buf = vim.fn.bufnr(diff.filename, true)

			vim.keymap.set("n", "D", function()
				vim.cmd("vert diffsplit " .. vim.b[buf].diff_filename)
				vim.cmd("wincmd p")
			end, { buffer = buf })
		end

		local bufs = {}
		for _, item in ipairs(items) do
			local buf = item.bufnr
			bufs[buf] = true
			if vim.fn.bufloaded(buf) == 1 then
				set_buf_stuff(buf, qflist)
			end
		end

		local g = vim.api.nvim_create_augroup(string.format("fugitive/qf:%d/diff", qfbufnr), { clear = true })
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
							vim.cmd("vert diffsplit " .. vim.b[buf].diff_filename)
							vim.cmd("wincmd p")
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
