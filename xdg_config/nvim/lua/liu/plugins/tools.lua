local utils = require("liu.utils")

return {
	{
		"tpope/vim-dadbod",
		-- integrates with: vim-dispatch (via b:dispatch), vim-flagship (status indicator)
		dependencies = {
			"gh-liu/vim-dbcp",
			dev = true,
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
	{
		"mistweaverco/kulala.nvim",
		-- depends on: snacks.picker (for UI pickers)
		-- integrates with: vim-dispatch (via b:dispatch), vim-flagship (status indicator)
		-- @need-install: go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
		-- @need-install: cargo install websocat
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
		"obsidian-nvim/obsidian.nvim",
		version = "*",
		cond = function()
			return vim.fn.isdirectory(".obsidian") ~= 0
		end,
		init = function()
			vim.api.nvim_create_autocmd("FileType", {
				group = utils.augroup("obsidian"),
				pattern = "markdown",
				callback = function(_)
					vim.wo[0][0].conceallevel = 1
				end,
			})
		end,
		opts = {
			legacy_commands = false,
			-- !for new
			-- note_id_func = function(title)
			-- 	local date = os.date("%Y-%m-%d_%H:%M")
			-- 	if title and title ~= "" then
			-- 		return date .. "_" .. title
			-- 	else
			-- 		return date
			-- 	end
			-- end,
			workspaces = {
				{
					name = "current",
					path = vim.fn.getcwd(),
				},
			},
			templates = {
				folder = ".templates",
				date_format = "%Y-%m-%d",
				time_format = "%H:%M",
			},
			daily_notes = {
				folder = "daily",
				date_format = "%Y-%m-%d_%H:%M",
				default_tags = { "daily-notes" },
			},
			footer = {
				enabled = true,
			},
		},
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
