return {
	{
		"stefandtw/quickfix-reflector.vim",
		init = function()
			vim.api.nvim_create_autocmd("VimLeavePre", {
				desc = "delete quickfix-(bufnr) buffers",
				callback = function(args)
					for _, buf in ipairs(vim.api.nvim_list_bufs()) do
						if vim.api.nvim_buf_get_name(buf):match("quickfix-%a") then
							vim.api.nvim_buf_delete(buf, { force = true })
						end
					end
				end,
			})
		end,
		-- event = "VeryLazy",
		ft = "qf",
	},
	{
		"craigmac/vim-mermaid",
		ft = "mermaid",
		init = function()
			-- bun install -g @mermaid-js/mermaid-cli
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "mermaid",
				callback = function(args)
					vim.b.dispatch = "mmdc -i % -o %:r:t.svg"

					vim.api.nvim_create_autocmd("BufWritePost", {
						buffer = args.buf,
						command = "Dispatch!",
					})
				end,
			})
		end,
	},
	{
		"LuaCATS/busted",
		lazy = true,
	},
	{
		"LuaCATS/luassert",
		lazy = true,
	},
}
