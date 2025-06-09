return {
	{
		"tpope/vim-dadbod",
		init = function()
			-- vim.keymap.set("n", "dq", "db#op_exec()", { expr = true })

			vim.cmd([[
			    xnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExeLine) db#op_exec() . '_'
				
				xmap yq  <Plug>(DBExe)
				nmap yq  <Plug>(DBExe)
				omap yq  <Plug>(DBExe)
				nmap yqq <Plug>(DBExeLine)
			]])
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
		"direnv/direnv.vim",
		ft = "direnv",
	},
	{
		"nvzone/showkeys",
		opts = {
			---@type 'bottom-left'|'bottom-right'|'bottom-center'|'top-left'|'top-right'|'top-center'
			position = "top-right",
		},
		cmd = "ShowkeysToggle",
	},
	{
		"craigmac/vim-mermaid",
		ft = "mermaid",
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
	{
		"gh-liu/nvim-stevedore",
		dev = true,
	},
	{
		"gh-liu/nvim-tasks",
		dev = true,
	},
}
