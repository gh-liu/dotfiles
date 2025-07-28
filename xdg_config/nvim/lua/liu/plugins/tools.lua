-- NOTE: add filetype plugins at bottom
return {
	{
		"tpope/vim-dadbod",
		init = function()
			-- vim.keymap.set("n", "dq", "db#op_exec()", { expr = true })

			vim.cmd([[
			    xnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExeLine) db#op_exec() . '_'
				
				" NOTE: y will be used in x mode
				"xmap yq  <Plug>(DBExe)
				"nmap yq  <Plug>(DBExe)
				"omap yq  <Plug>(DBExe)
				"nmap yqq <Plug>(DBExeLine)
			]])

			-- NOTE: define your adapters:
			-- use `g:db_adapter_ADAPTERNAME` to define methods of you adapter
			-- https://github.com/tpope/vim-dadbod/blob/e95afed23712f969f83b4857a24cf9d59114c2e6/autoload/db/adapter.vim#L14
			-- call adapter methods by `db#adapter#call(arg1, adapter_method, ...)`
		end,
	},
	{
		"mistweaverco/kulala.nvim",
		init = function()
			vim.api.nvim_create_autocmd({ "FileType" }, {
				pattern = "http",
				callback = function(ev)
					local buffer = ev.buf
					vim.keymap.set("n", "[[", require("kulala").jump_prev, { buffer = buffer })
					vim.keymap.set("n", "]]", require("kulala").jump_next, { buffer = buffer })

					vim.keymap.set("n", "<localleader>r", require("kulala").run, { buffer = buffer })
					vim.keymap.set("n", "<localleader>R", require("kulala").replay, { buffer = buffer })
					vim.keymap.set("n", "<localleader>c", require("kulala").copy, { buffer = buffer })

					vim.b.dispatch = [[:lua require("kulala").run()]]

					vim.b.UserBufFlagship = function()
						local CONFIG = require("kulala.config")
						-- return "kulala:" .. (vim.g.kulala_selected_env or CONFIG.get().default_env)
						local icon = CONFIG.get().icons.lualine
						return icon .. (vim.g.kulala_selected_env or CONFIG.get().default_env)
					end

					vim.t.sp_tab_title = "kulala"
				end,
			})
		end,
		ft = { "http" },
		opts = {
			global_keymaps = false,
		},
	},
	{
		"uga-rosa/ccc.nvim",
		cmd = { "CccPick", "CccHighlighterToggle" },
		config = function()
			local ccc = require("ccc")
			ccc.setup({
				highlighter = {
					auto_enable = true,
					lsp = true,
				},
			})
		end,
	},
	{
		"dhananjaylatkar/cscope_maps.nvim",
		enabled = false,
		opts = {
			disable_maps = true,
			prefix = false,
		},
		cmd = { "Cs" },
	},
	{
		"gh-liu/nvim-stevedore",
		dev = true,
		init = function()
			vim.g.stevedore_runtime = "stevedore.runtime.docker"
		end,
	},
	-- filetype plugins below
	{
		"direnv/direnv.vim",
		ft = "direnv",
	},
	{
		"craigmac/vim-mermaid",
		ft = "mermaid",
		init = function()
			-- @need-install: bun install -g @mermaid-js/mermaid-cli
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
		"mmarchini/bpftrace.vim",
		ft = "bpftrace",
		init = function()
			vim.api.nvim_create_autocmd("FileType", {
				pattern = "bpftrace",
				callback = function()
					vim.bo.omnifunc = "syntaxcomplete#Complete"
					vim.b.blink_cmp_provider = { "buffer", "omni" }
				end,
			})
		end,
	},
}
