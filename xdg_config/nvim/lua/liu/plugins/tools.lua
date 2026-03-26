local utils = require("liu.utils")

return {
	-- Database interface for SQL queries with async execution and result display
	{
		"tpope/vim-dadbod",
		-- integrates with: vim-dispatch (via b:dispatch), vim-flagship (status indicator)
		dependencies = {
			-- Dadbod connection picker/manager
			{ "gh-liu/vim-dbcp", enabled = false, dev = true },
		},
		init = function()
			vim.cmd([[
			    xnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExe)     db#op_exec()
				nnoremap <expr> <Plug>(DBExeLine) db#op_exec() . '_'

				xmap gQ  <Plug>(DBExe)
				nmap gQ  <Plug>(DBExe)
				omap gQ  <Plug>(DBExe)
				nmap gQQ <Plug>(DBExeLine)
				nmap gQ? <cmd> echo get(g:,"db",get(b:,"db","no db")) <cr>

				augroup liu_dadbod
				  autocmd!
				  autocmd User Flags call Hoist('buffer', 99, '%{flagship#surround(toupper(matchstr(get(b:, "db", ""), "^[^:]*")))}')
				augroup END
			]])

			-- NOTE: define your adapters:
			-- use `g:db_adapter_ADAPTERNAME` to define methods of you adapter
			-- https://github.com/tpope/vim-dadbod/blob/e95afed23712f969f83b4857a24cf9d59114c2e6/autoload/db/adapter.vim#L14
			-- call adapter methods by `db#adapter#call(arg1, adapter_method, ...)`
		end,
	},
	-- HTTP/REST client for testing APIs with .http files and environment support
	{
		"mistweaverco/kulala.nvim",
		-- depends on: snacks.picker (for UI pickers)
		-- integrates with: vim-dispatch (via b:dispatch), vim-flagship (status indicator)
		init = function()
			vim.api.nvim_create_autocmd({ "FileType" }, {
				group = utils.augroup("kulala"),
				pattern = "http",
				callback = function(ev)
					local buffer = ev.buf
					local kulala = require("kulala")
					vim.keymap.set("n", "[[", kulala.jump_prev, { buffer = buffer, desc = "Jump to previous request" })
					vim.keymap.set("n", "]]", kulala.jump_next, { buffer = buffer, desc = "Jump to next request" })

					vim.keymap.set("n", "<localleader>r", kulala.run, { buffer = buffer, desc = "Run HTTP request" })
					vim.keymap.set(
						"n",
						"<localleader>R",
						kulala.replay,
						{ buffer = buffer, desc = "Replay last request" }
					)
					vim.keymap.set("n", "<localleader>cc", kulala.copy, { buffer = buffer, desc = "Copy curl command" })
					vim.keymap.set(
						"n",
						"<localleader>se",
						kulala.set_selected_env,
						{ buffer = buffer, desc = "Set environment" }
					)

					vim.b.dispatch = [[:lua require("kulala").run()]]

					-- Integrates with vim-flagship for status display
					vim.b.UserBufFlagship = function()
						local CONFIG = require("kulala.config")
						local icon = CONFIG.get().icons.lualine
						return icon .. (vim.g.kulala_selected_env or CONFIG.get().default_env)
					end

					vim.t.sp_tab_title = "kulala"
				end,
			})

			vim.api.nvim_create_autocmd("BufEnter", {
				group = utils.augroup("kulala_ui"),
				pattern = "kulala://ui",
				callback = function(data)
					if vim.fn.winnr("$") < 2 then
						vim.cmd.bdelete({ bang = true, mods = { silent = true } })
					end
					vim.wo[0][0].statusline = "%y"
				end,
			})
		end,
		ft = { "http" },
		opts = {
			global_keymaps = false,
			certificates = {},
			custom_dynamic_variables = {},
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
	-- Color picker/editor with highlighter for color codes in buffers
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
	-- Exit nested insert/command mode with single ESC regardless of nesting depth
	{
		"brianhuster/unnest.nvim",
	},
	-- Custom test runner wrapper for various testing frameworks
	{
		"gh-liu/nvim-tester",
		dev = true,
	},
	-- Table formatter for markdown and text tables with alignment support
	{
		"numEricL/table.vim",
		init = function()
			vim.g.table_disable_mappings = 1
		end,
	},
}
