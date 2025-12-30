-- NOTE: not editor features?
return {
	{
		"tpope/vim-dadbod",
		init = function()
			-- vim.keymap.set("n", "dq", "db#op_exec()", { expr = true })

			vim.cmd([[
			    xnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExeLine) db#op_exec() . '_'
				
				xmap gQ  <Plug>(DBExe)
				nmap gQ  <Plug>(DBExe)
				omap gQ  <Plug>(DBExe)
				nmap gQQ <Plug>(DBExeLine)
				nmap gQ? <cmd> echo get(g:,"db",get(b:,"db","no db")) <cr>

				autocmd User Flags call Hoist('buffer', 99, '%{flagship#surround(toupper(matchstr(get(b:, "db", ""), "^[^:]*")))}')
			]])

			-- NOTE: define your adapters:
			-- use `g:db_adapter_ADAPTERNAME` to define methods of you adapter
			-- https://github.com/tpope/vim-dadbod/blob/e95afed23712f969f83b4857a24cf9d59114c2e6/autoload/db/adapter.vim#L14
			-- call adapter methods by `db#adapter#call(arg1, adapter_method, ...)`
		end,
	},
	{
		"mistweaverco/kulala.nvim",
		-- @need-install: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
		-- @need-install: cargo install websocat
		init = function()
			vim.api.nvim_create_autocmd({ "FileType" }, {
				pattern = "http",
				callback = function(ev)
					local buffer = ev.buf
					vim.keymap.set("n", "[[", require("kulala").jump_prev, { buffer = buffer })
					vim.keymap.set("n", "]]", require("kulala").jump_next, { buffer = buffer })

					vim.keymap.set("n", "<localleader>r", require("kulala").run, { buffer = buffer })
					vim.keymap.set("n", "<localleader>R", require("kulala").replay, { buffer = buffer })
					vim.keymap.set("n", "<localleader>cc", require("kulala").copy, { buffer = buffer })
					vim.keymap.set("n", "<localleader>se", require("kulala").set_selected_env, { buffer = buffer })

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

			vim.api.nvim_create_autocmd("BufEnter", {
				pattern = "kulala://ui",
				callback = function(data)
					if vim.fn.winnr("$") < 2 then
						vim.cmd.bdelete({ bang = true, mods = { silent = true } })
					end
					vim.cmd("setlocal stl=%y")
				end,
			})
		end,
		ft = { "http" },
		opts = {
			-- :h kulala.configuration-options-configuration-options
			global_keymaps = false,
			-- https://neovim.getkulala.net/docs/getting-started/configuration-options#certificates
			certificates = {},
			custom_dynamic_variables = {}, ---@type { [string]: fun():string }[]
			additional_curl_options = { "--noproxy", "*" },
			ui = {
				pickers = {
					snacks = {
						layout = function()
							local has_snacks, snacks_picker = pcall(require, "snacks.picker")
							return not has_snacks and {}
								or vim.tbl_deep_extend("force", snacks_picker.config.layout("default"), {})
						end,
					},
				},
			},
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
		"brianhuster/unnest.nvim",
	},
	{
		"gh-liu/nvim-tester",
		dev = true,
	},
	{
		"letieu/jira.nvim",
		cond = function()
			return vim.env.JIRA_BASE
		end,
		opts = {
			jira = {
				base = vim.env.JIRA_BASE,
				email = vim.env.JIRA_EMAIL,
				token = vim.env.JIRA_TOKEN,
				limit = 50,
			},
		},
	},
}
