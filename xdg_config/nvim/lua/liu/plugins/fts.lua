return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		opts = {
			code = {
				sign = false,
				border = "none",
			},
			pipe_table = { enabled = false },
		},
		ft = "markdown",
	},
	-- Edit quickfix list items directly and apply changes back to source files
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
	-- Syntax highlighting and preview for Mermaid diagram files
	{
		"craigmac/vim-mermaid",
		ft = "mermaid",
		init = function()
			-- @need-install: cargo install --git https://github.com/1jehuang/mermaid-rs-renderer
			-- @need-install: go install github.com/AlexanderGrooff/mermaid-ascii@latest
			-- how:
			-- 1. :%!mermaid-ascii -f %
			-- 2. :'<,'>%!mermaid-ascii
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "mermaid",
				callback = function(args)
					vim.b.dispatch = "mmdr -i % -o %:r:t.svg"

					vim.api.nvim_create_autocmd("BufWritePost", {
						buffer = args.buf,
						command = "Dispatch!",
					})
				end,
			})
		end,
	},
	-- Busted testing framework type definitions for Lua development
	{
		"LuaCATS/busted",
		lazy = true,
	},
	-- Luassert assertion library type definitions for Lua testing
	{
		"LuaCATS/luassert",
		lazy = true,
	},
}
