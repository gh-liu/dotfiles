vim.api.nvim_create_autocmd({ "QuickFixCmdPost" }, {
	pattern = "cfugitive-difftool",
	callback = function()
		local qflist = vim.fn.getqflist({ items = 0 })
		local items = qflist.items

		local bufs = {}
		for _, item in ipairs(items) do
			local buf = item.bufnr
			bufs[buf] = true
		end

		-- https://github.com/tpope/vim-fugitive/blob/593f831d6f6d779cbabb70a4d1e6b1b1936a88af/autoload/fugitive.vim#L3072
		-- seems all fugitive files be set option `bufhidden=delete`, so toggle between qf items will cause the buffer be deleted
		vim.api.nvim_create_autocmd("BufAdd", {
			callback = function(args)
				local buf = args.buf
				if bufs[buf] then
					vim.keymap.set("n", "D", function()
						local qf = vim.fn.getqflist({ context = 0, idx = 0 })
						local diffs = qf.context.items[qf.idx].diff
						local diff = diffs[1]
						vim.b[buf].diff_buf = vim.fn.bufnr(diff.filename, true)

						vim.cmd("vert diffsplit " .. diff.filename)
						vim.cmd("wincmd p")
					end, { buffer = buf })
				end
			end,
		})
		vim.api.nvim_create_autocmd("BufDelete", {
			callback = function(args)
				local buf = args.buf
				if bufs[buf] then
					local diff_buf = vim.b[buf].diff_buf
					if diff_buf and vim.api.nvim_buf_is_valid(diff_buf) then
						vim.api.nvim_buf_delete(diff_buf, { force = true, unload = true })
					end
				end
			end,
		})
	end,
})
