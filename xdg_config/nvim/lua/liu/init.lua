local fn = vim.fn
local uv = vim.uv
local keymap = vim.keymap

local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup
local create_command = api.nvim_create_user_command

local lsp = vim.lsp

local paire_move = require("liu.utils.pair_move")

-- Global Things {{{1
_G.config = {
	borders = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
	colors = require("liu.nord").colors,
	icons = require("liu.icons"),
}

_G.get_hl = require("liu.utils.color").get_hl_color

---@param highlights table
_G.set_hls = function(highlights)
	for group, opts in pairs(highlights) do
		api.nvim_set_hl(0, group, opts)
	end
end

---@param cmds table
_G.set_cmds = function(cmds)
	for key, cmd in pairs(cmds) do
		create_command(key, cmd, { bang = true, nargs = 0 })
	end
end
-- }}}

-- helper functions {{{
---@param group_name string
local liu_augroup = function(group_name)
	return augroup("liu/" .. group_name, { clear = true })
end

---@param buf integer
---@param s function
---@param v function
---@param t function
local open_maps = function(buf, s, v, t)
	local map = vim.keymap
	map.set("n", "<C-s>", s, { buffer = buf, desc = "split s" })
	map.set("n", "<C-v>", v, { buffer = buf, desc = "split v" })
	map.set("n", "<C-t>", t, { buffer = buf, desc = "split t" })
end

---@param ms integer
---@param fn function
local debounce = function(ms, fn)
	---@diagnostic disable-next-line: undefined-field
	local timer = uv.new_timer()
	return function(...)
		local argv = { ... }
		timer:start(ms, 0, function()
			timer:stop()
			vim.schedule_wrap(fn)(unpack(argv))
		end)
	end
end
-- }}}

-- Plugins {{{1
local load_plugin_config = function(plugin)
	require("liu.plugins." .. plugin)
end

require("lazy").setup(
	{
		-- libs {{{2
		{
			"nvim-lua/plenary.nvim",
			lazy = true,
		},
		-- }}}

		-- treesitter {{{2
		{
			"nvim-treesitter/nvim-treesitter",
			event = "VeryLazy",
			build = ":TSUpdate",
			opts = {
				ensure_installed = "all",
				ignore_install = {},
				sync_install = false,
				auto_install = true,
				highlight = {
					enable = true,
					disable = function(lang, buf)
						local max_filesize = 256 * 1024 -- 256 KB
						---@diagnostic disable-next-line: undefined-field
						local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
						if ok and stats and stats.size > max_filesize then
							return true
						end
					end,
				},
				indent = { enable = true },
				incremental_selection = { enable = false },
			},
			config = function(self, opts)
				require("nvim-treesitter.configs").setup(opts)

				local edit = require("liu.treesitter.edit")
				vim.keymap.set("n", "<leader>rn", edit.smart_rename)

				-- local nav = require("liu.treesitter.navigation")
				-- nav.map_object_pair_move("f", "@function.outer", true)
				-- nav.map_object_pair_move("F", "@function.outer", false)

				local usage = require("liu.treesitter.usage")
				vim.keymap.set("n", "]v", usage.goto_next)
				vim.keymap.set("n", "[v", usage.goto_prev)
			end,
		},
		{
			"nvim-treesitter/nvim-treesitter-context",
			event = "VeryLazy",
			opts = {
				enable = true,
				line_numbers = true,
				separator = "-",
				-- on_attach = function(buf) end,
			},
			config = function(self, opts)
				local ts_ctx = require("treesitter-context")
				ts_ctx.setup(opts)

				keymap.set("n", "cO", function()
					ts_ctx.go_to_context(vim.v.count1)
				end, { desc = "go to [cO]ntext" })

				set_hls({
					TreesitterContextSeparator = { fg = config.colors.gray },
				})
			end,
		},
		{
			-- "nvim-treesitter/nvim-treesitter-textobjects",
			"gh-liu/nvim-treesitter-textobjects",
			event = "VeryLazy",
		},
		-- }}}

		-- lsp {{{2
		{
			"neovim/nvim-lspconfig",
			event = "VeryLazy",
			config = function(self, opts)
				load_plugin_config("lsp")
			end,
		},
		{
			"kosayoda/nvim-lightbulb",
			event = "LspAttach",
			opts = {
				autocmd = { enabled = true },
				priority = 20, -- priority of dap signs is 21
				sign = {
					enabled = true,
					text = config.icons.bulb,
				},
			},
		},
		{
			"Wansmer/symbol-usage.nvim",
			enabled = false,
			event = "LspAttach",
			opts = {
				hl = { link = "LspInlayHint" },
				vt_position = "end_of_line",
				references = { enabled = true, include_declaration = false },
				definition = { enabled = false },
				implementation = { enabled = true },
			},
			config = function(_, opts)
				local SymbolKind = lsp.protocol.SymbolKind
				opts = vim.tbl_extend("force", opts, {
					filetypes = {
						go = {
							kinds = {
								SymbolKind.Function,
								SymbolKind.Method,
								SymbolKind.Interface,
								SymbolKind.Struct,
							},
							kinds_filter = {
								[SymbolKind.Method] = {
									function(data)
										if data.parent.kind == SymbolKind.Interface then
											return false
										end
										return true
									end,
								},
							},
						},
						lua = {
							kinds = {
								SymbolKind.Function,
							},
						},
					},
				})

				require("symbol-usage").setup(opts)
			end,
		},
		-- }}}

		-- dap {{{2
		{
			"mfussenegger/nvim-dap",
			keys = {
				"<leader>dc",
				"<leader>db",
			},
			cmd = {
				"DapContinue",
				"DapToggleBreakpoint",
				"DapStart",
				"DapRunOSV",
			},
			dependencies = {
				{
					"rcarriga/nvim-dap-ui",
					dependencies = { "nvim-neotest/nvim-nio" },
				},
				{
					"jbyuki/one-small-step-for-vimkind",
					config = function(self, opts)
						api.nvim_create_user_command("DapRunOSV", function()
							require("osv").launch({ port = 8086 })
						end, { nargs = 0 })
					end,
				},
			},
			config = function(self, opts)
				load_plugin_config("dap")
			end,
		},
		-- }}}

		-- diagnostic {{{2
		{
			"mfussenegger/nvim-lint",
			lazy = true,
			init = function(self)
				local linters_by_ft = self.opts.linters_by_ft
				autocmd("FileType", {
					pattern = vim.tbl_keys(linters_by_ft),
					callback = function(ev)
						local bufnr = ev.buf
						local try_lint = debounce(500, function()
							if api.nvim_buf_is_valid(bufnr) then
								api.nvim_buf_call(bufnr, function()
									require("lint").try_lint()
								end)
							end
						end)
						autocmd({
							"BufWritePost",
							"BufReadPost",
							"InsertLeave",
							"TextChanged",
						}, {
							group = liu_augroup("nvim-lint_" .. tostring(bufnr)),
							callback = function(ev)
								try_lint()
							end,
							buffer = bufnr,
						})
					end,
					desc = "setup nvim-lint",
				})
			end,
			opts = {
				linters_by_ft = {
					go = { "golangcilint" },
					proto = { "buf_lint" },
				},
			},
			config = function(self, opts)
				require("lint").linters_by_ft = opts.linters_by_ft
			end,
		},
		-- }}}

		-- text edit {{{2
		{
			"stevearc/conform.nvim",
			lazy = true,
			init = function(self)
				vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
			end,
			keys = {
				{
					"<leader>=",
					function()
						require("conform").format({ lsp_fallback = true })
					end,
				},
			},
			ft = function(self, ft)
				return vim.tbl_keys(self.opts.formatters_by_ft)
			end,
			opts = {
				formatters_by_ft = {
					go = { "goimports", "gofumpt" },
					json = { "jq" },
					just = { "just" },
					lua = { "stylua" },
					proto = { "buf" },
					rust = { "rustfmt" },
					sh = { "shfmt" },
					sql = { "sql_formatter" },
					zig = { "zigfmt" },
					zsh = { "shfmt" },
				},
			},
			config = function(self, opts)
				opts.format_on_save = function(bufnr)
					if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
						return
					end

					return { timeout_ms = 500, lsp_fallback = true }
				end
				require("conform").setup(opts)
			end,
		},
		{
			"monaqa/dial.nvim",
			keys = {
				{ "<C-a>", "<Plug>(dial-increment)", mode = { "n", "x" } },
				{ "<C-x>", "<Plug>(dial-decrement)", mode = { "n", "x" } },
				{ "g<C-a>", "g<Plug>(dial-increment)", mode = { "n", "x" } },
				{ "g<C-x>", "g<Plug>(dial-decrement)", mode = { "n", "x" } },
			},
			config = function()
				local config = require("dial.config")
				local augend = require("dial.augend")

				local default = {
					augend.constant.alias.bool,
					augend.integer.alias.hex,
					augend.integer.alias.decimal,
					-- augend.date.new({ pattern = "%Y/%m/%d", default_kind = "day" }),
					-- augend.date.new({ pattern = "%Y-%m-%d", default_kind = "day" }),
					-- augend.paren.alias.brackets,
				}

				config.augends:register_group({
					default = default,
				})

				config.augends:on_filetype({
					go = vim.list_extend(
						{ augend.constant.new({ elements = { "&&", "||" }, word = false, cyclic = true }) },
						default
					),
					lua = vim.list_extend(
						{ augend.constant.new({ elements = { "and", "or" }, word = true, cyclic = true }) },
						default
					),
					markdown = vim.list_extend({ augend.misc.alias.markdown_header }, default),
					rust = vim.list_extend({}, default),
					toml = vim.list_extend({ augend.semver.alias.semver }, default),
					zig = vim.list_extend({}, default),
				})
			end,
		},
		{
			"Wansmer/treesj",
			enabled = true,
			keys = {
				{
					"gJ",
					":TSJJoin<CR>",
					silent = true,
					desc = "joining blocks of code like arrays, hashes, statements, objects, dictionaries, etc.",
				},
				{
					"gS",
					":TSJSplit<CR>",
					silent = true,
					desc = "splitting blocks of code like arrays, hashes, statements, objects, dictionaries, etc.",
				},
			},
			cmd = { "TSJSplit", "TSJJoin" },
			opts = {
				use_default_keymaps = false,
				max_join_length = 300,
			},
		},
		{
			"echasnovski/mini.move",
			keys = {
				{ "<M-h>", mode = { "n", "x" } },
				{ "<M-j>", mode = { "n", "x" } },
				{ "<M-k>", mode = { "n", "x" } },
				{ "<M-l>", mode = { "n", "x" } },
			},
			config = function(self, opts)
				local keys = self.keys
				if not keys then
					return
				end

				require("mini.move").setup({
					mappings = {
						-- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
						left = keys[1][1],
						down = keys[2][1],
						up = keys[3][1],
						right = keys[4][1],
						-- Move current line in Normal mode
						line_left = keys[1][1],
						line_down = keys[2][1],
						line_up = keys[3][1],
						line_right = keys[4][1],
					},
				})
			end,
		},
		{
			"echasnovski/mini.surround",
			keys = {
				{ "ys", mode = { "x", "n" } },
				{ "ds", mode = { "n" } },
				{ "cs", mode = { "n" } },
			},
			config = function(self, _)
				local keys = self.keys
				if not keys then
					return
				end

				local ts_input = require("mini.surround").gen_spec.input.treesitter
				local opts = {
					-- Module mappings. Use `''` (empty string) to disable one.
					mappings = {
						add = keys[1][1], -- Add surrounding in Normal and Visual modes
						delete = keys[2][1], -- Delete surrounding
						replace = keys[3][1], -- Replace surrounding

						find = "", -- Find surrounding (to the right)
						find_left = "", -- Find surrounding (to the left)
						highlight = "", -- Highlight surrounding
						update_n_lines = "", -- Update `n_lines`

						suffix_last = "p", -- Suffix to search with "prev" method
						suffix_next = "n", -- Suffix to search with "next" method
					},
					custom_textobjects = {
						f = ts_input({ outer = "@call.outer", inner = "@call.inner" }),
					},
					n_lines = 30,
					search_method = "cover",
				}

				require("mini.surround").setup(opts)
			end,
		},
		{
			"echasnovski/mini.operators",
			keys = {
				{ "s", mode = { "n", "x" } },
				{ "S", "<cmd>normal s$<cr>", silent = true },
				{ "cx", mode = { "n", "x" } },
				{ "g=", mode = { "n", "x" } },
			},
			opts = {
				replace = {
					prefix = "s",
					reindent_linewise = true,
				},
				exchange = {
					prefix = "cx",
					reindent_linewise = true,
				},
				evaluate = { prefix = "g=" },
				multiply = { prefix = "" },
				sort = { prefix = "" },
			},
		},
		{
			"echasnovski/mini.align",
			keys = {
				{ "ga", mode = { "n", "x" } },
				{ "gA", mode = { "n", "x" } },
			},
			config = function(self, opts)
				require("mini.align").setup({
					mappings = {
						start = self.keys[1][1],
						start_with_preview = self.keys[2][1],
					},
				})
			end,
		},
		{
			"tpope/vim-abolish",
			init = function(self)
				vim.g.abolish_save_file = fn.stdpath("config") .. "/after/plugin/abolish.vim"
			end,
			keys = { "cr" },
			cmd = {
				"Abolish",
				"Subvert",
				"S",
			},
		},
		{
			"danymat/neogen",
			cmd = { "Neogen" },
			opts = {
				snippet_engine = "luasnip",
				languages = {
					lua = {
						template = { annotation_convention = "emmylua" },
					},
				},
			},
		},
		{
			"cshuaimin/ssr.nvim",
			enabled = false,
			keys = {
				{
					"<leader>R",
					function()
						require("ssr").open()
					end,
					mode = { "n", "x" },
					desc = "Structural Search + Replace",
				},
			},
			opts = {},
		},
		{
			"mizlan/iswap.nvim",
			cmd = {
				"ISwap",
				"ISwapWith",
				"ISwapNode",
				"ISwapNodeWith",
			},
			opts = {},
		},
		-- }}}

		-- ui {{{2
		{
			"nvim-tree/nvim-web-devicons",
			lazy = true,
		},
		{
			"stevearc/dressing.nvim",
			lazy = true,
			init = function()
				---@diagnostic disable-next-line: duplicate-set-field
				vim.ui.select = function(...)
					require("lazy").load({ plugins = { "dressing.nvim" } })
					return vim.ui.select(...)
				end

				---@diagnostic disable-next-line: duplicate-set-field
				vim.ui.input = function(...)
					require("lazy").load({ plugins = { "dressing.nvim" } })
					return vim.ui.input(...)
				end
			end,
			---@diagnostic disable-next-line: duplicate-set-field
			opts = {
				input = {
					enabled = true,
					border = config.borders,
				},
				select = {
					enabled = true,
					backend = { "telescope", "builtin" },
					builtin = { border = config.borders },
				},
			},
		},
		{
			"utilyre/sentiment.nvim",
			enabled = true,
			event = "VeryLazy",
			init = function()
				-- `matchparen.vim` needs to be disabled manually in case of lazy loading
				vim.g.loaded_matchparen = 1
			end,
			opts = {},
		},
		{
			"j-hui/fidget.nvim",
			enabled = true,
			event = "LspAttach",
			-- lazy = true,
			-- init = function()
			-- 	local notify = nil
			-- 	---@diagnostic disable-next-line: duplicate-set-field
			-- 	vim.notify = function(...)
			-- 		if not notify then
			-- 			notify = require("fidget").notify
			-- 		end
			-- 		notify(...)
			-- 	end
			-- end,
			cmd = { "Fidget" },
			opts = {
				-- LSP progress
				progress = {},
				-- Notification
				notification = {
					-- Automatically override vim.notify() with Fidget
					override_vim_notify = false,
				},
			},
		},
		{
			"lewis6991/hover.nvim",
			keys = { "K", "gK" },
			config = function()
				require("hover").setup({
					init = function()
						require("hover.providers.lsp")
						require("hover.providers.dap")
						require("hover.providers.man")
					end,
					preview_opts = {
						border = config.borders,
					},
					preview_window = false,
					title = true,
				})

				local h = require("hover")
				keymap.set("n", "K", function()
					local hover_win = vim.b.hover_preview
					if hover_win and api.nvim_win_is_valid(hover_win) then
						api.nvim_set_current_win(hover_win)
					else
						h.hover()
					end
				end, { desc = "hover.nvim" })
				keymap.set("n", "gK", h.hover_select, { desc = "hover.nvim (select)" })

				create_command("HoverPrec", function(opts)
					h.hover_switch("previous")
				end, { nargs = 0, desc = "hover.nvim (previous source)" })
				create_command("HoverNext", function(opts)
					h.hover_switch("next")
				end, { nargs = 0, desc = "hover.nvim (next source)" })
			end,
		},
		--}}}

		-- fuzzy finder(Telescope) {{{2
		{
			"nvim-telescope/telescope.nvim",
			-- event = "VeryLazy",
			init = function(self)
				api.nvim_create_autocmd("LspAttach", {
					group = liu_augroup("lsp_attach_telescope_keymaps"),
					callback = function(args)
						local map = function(l, r, desc, opts)
							keymap.set("n", l, function()
								local opts = opts or {}
								require("telescope.builtin")[r](opts)
							end, { buffer = args.buf, desc = desc })
						end

						map("<leader>ds", "lsp_document_symbols", "LSP [D]ocument [S]ymbols of the current buffer")
						map("gd", "lsp_definitions", "[G]oto [D]efinition")
						map("gy", "lsp_type_definitions", "[G]oto T[y]pe Definition")
						map("gi", "lsp_implementations", "[G]oto [I]mplementation")
						map("gr", "lsp_references", "[G]oto [R]eferences", { include_declaration = false })

						-- map("gI", "lsp_incoming_calls", "[G]oto [I]ncomingCalls") -- this function as callee
						-- map("gO", "lsp_outgoing_calls", "[G]oto [O]utgoingCalls") -- this function as caller
					end,
				})
			end,
			cmd = { "Telescope" },
			keys = function(self, keys)
				local maps = {
					["<leader>so"] = { fn = "oldfiles", desc = "[S]earch recently [O]pened files" },
					["<leader>sf"] = { fn = "find_files", desc = "[S]earch [F]iles" },
					["<leader>sb"] = { fn = "buffers", desc = "[S]earch existing [B]uffers" },
					["<leader>sg"] = { fn = "live_grep", desc = "[S]earch by [G]rep" },
					["<leader>s/"] = { fn = "current_buffer_fuzzy_find", desc = "[S]earch in Current Buffer like [/]" },
					["<leader>ss"] = { fn = "search_history", desc = "[S]earch [S]earch History" },
					["<leader>sm"] = { fn = "marks", desc = "[S]earch [M]ark" },
					["<leader>sj"] = { fn = "jumplist", desc = "[S]et [J]umplist" },
					["<leader>sr"] = { fn = "registers", desc = "[S]earch [R]egisters" },
					["<leader>st"] = { fn = "filetypes", desc = "[S]et File[t]ype" },
					["<leader>sh"] = { fn = "help_tags", desc = "[S]earch [H]elp" },
					["<leader>sw"] = { fn = "grep_string", desc = "[S]earch [W]ord" },
					["<leader>sd"] = { fn = "diagnostics", desc = "[S]earch [D]iagnostics" },
					-- override by builtin.lsp_document_symbols
					["<leader>ds"] = { fn = "diagnostics", desc = "Treesitter [D]ocument [S]ymbols" },

					["<leader>;"] = { fn = "commands", desc = "List Commands" },
				}

				local keys = {}
				for key, value in pairs(maps) do
					table.insert(keys, {
						key,
						function()
							require("telescope.builtin")[value.fn]()
						end,
						desc = value.desc,
					})
				end
				return keys
			end,
			dependencies = {
				{
					"nvim-telescope/telescope-fzf-native.nvim",
					cond = function()
						return fn.executable("make") == 1
					end,
					build = "make",
					config = function()
						require("telescope").load_extension("fzf")
					end,
				},
			},
			config = function()
				local A = require("telescope.actions")
				local utils = require("telescope.utils")
				local action_state = require("telescope.actions.state")

				-- git stash commands {{{
				---@param prompt_bufnr integer
				---@param action_name string
				---@param stash_sub_command string
				---@param gen_cmd_fn function(string)
				local git_stash_command = function(prompt_bufnr, action_name, stash_sub_command, gen_cmd_fn)
					local selection = action_state.get_selected_entry()
					if selection == nil then
						utils.__warn_no_selection("actions." .. action_name)
						return
					end
					A.close(prompt_bufnr)

					local index = selection.value
					local _, ret, stderr = utils.get_os_command_output(gen_cmd_fn(index))
					if ret == 0 then
						utils.notify("actions." .. action_name, {
							msg = string.format("%sed: '%s' ", stash_sub_command, index),
							level = "INFO",
						})
					else
						utils.notify("actions." .. action_name, {
							msg = string.format(
								"Error when %sing: %s. Git returned: '%s'",
								stash_sub_command,
								index,
								table.concat(stderr, " ")
							),
							level = "ERROR",
						})
					end
				end
				-- }}}

				local user_action = {
					git_pop_stash = function(prompt_bufnr)
						git_stash_command(prompt_bufnr, "git_pop_stash", "pop", function(index)
							return { "git", "stash", "pop", "--index", index }
						end)
					end,
					git_drop_stash = function(prompt_bufnr)
						git_stash_command(prompt_bufnr, "git_drop_stash", "drop", function(index)
							return { "git", "stash", "drop", index }
						end)
					end,
				}

				local borders = config.borders

				require("telescope").setup({
					-- Global: Default configuration for telescope
					defaults = {
						-- https://github.com/nvim-telescope/telescope.nvim#default-mappings
						default_mappings = {
							i = {
								["<C-n>"] = A.move_selection_next,
								["<C-p>"] = A.move_selection_previous,
								["<Down>"] = A.move_selection_next,
								["<Up>"] = A.move_selection_previous,

								["<C-c>"] = A.close,
								["<esc>"] = A.close,

								["<CR>"] = A.select_default,
								["<C-s>"] = A.select_horizontal,
								["<C-v>"] = A.select_vertical,
								["<C-t>"] = A.select_tab,

								["<C-u>"] = A.preview_scrolling_up,
								["<C-d>"] = A.preview_scrolling_down,
								["<M-j>"] = A.preview_scrolling_down,
								["<M-k>"] = A.preview_scrolling_up,
								["<M-h>"] = A.preview_scrolling_left,
								["<M-l>"] = A.preview_scrolling_right,

								["<Tab>"] = A.toggle_selection + A.move_selection_worse,
								["<S-Tab>"] = A.toggle_selection + A.move_selection_better,
								["<C-q>"] = A.send_to_qflist + A.open_qflist,
								["<M-q>"] = A.send_selected_to_qflist + A.open_qflist,

								-- ["<C-l>"] = actions.send_to_loclist + actions.open_loclist,
								["<C-l>"] = A.complete_tag,

								["<C-/>"] = A.which_key,
								["<C-_>"] = A.which_key, -- keys from pressing <C-/>

								["<C-w>"] = { "<c-s-w>", type = "command" },
								["<C-r><C-w>"] = A.insert_original_cword,

								["<C-j>"] = A.cycle_history_next,
								["<C-k>"] = A.cycle_history_prev,
							},
							n = {
								["<esc>"] = A.close,
								["<C-c>"] = A.close,

								["<CR>"] = A.select_default,

								["<C-s>"] = A.select_horizontal,
								["<C-v>"] = A.select_vertical,
								["<C-t>"] = A.select_tab,

								["<Tab>"] = A.toggle_selection + A.move_selection_worse,
								["<S-Tab>"] = A.toggle_selection + A.move_selection_better,
								["<C-q>"] = A.send_to_qflist + A.open_qflist,
								["<M-q>"] = A.send_selected_to_qflist + A.open_qflist,

								["j"] = A.move_selection_next,
								["k"] = A.move_selection_previous,
								["<Down>"] = A.move_selection_next,
								["<Up>"] = A.move_selection_previous,
								["gg"] = A.move_to_top,
								["G"] = A.move_to_bottom,

								["<C-u>"] = A.preview_scrolling_up,
								["<C-d>"] = A.preview_scrolling_down,
								["<M-j>"] = A.preview_scrolling_down,
								["<M-k>"] = A.preview_scrolling_up,
								["<M-h>"] = A.preview_scrolling_left,
								["<M-l>"] = A.preview_scrolling_right,

								["?"] = A.which_key,
							},
						},
						-- stylua: ignore start
						borderchars = { borders[2], borders[4], borders[6], borders[8], borders[1], borders[3], borders[5], borders[7] },
						-- stylua: ignore end
						layout_config = {
							horizontal = { prompt_position = "top", preview_width = 0.6, results_width = 0.8 },
							vertical = { mirror = false },
							width = 0.8,
							height = 0.8,
							preview_cutoff = 120,
						},
						-- winblend = 10,
						sorting_strategy = "ascending",
						path_display = {
							"truncate",
							-- shorten = { len = 3, exclude = { -1, -2 } },
						},
						file_ignore_patterns = { -- lua regex
							".git/",
							-- "target/", -- rust
							-- "zig%-out/", -- zig
							-- "zig%-cache/", -- zig
						},
					},
					-- Individual: Default configuration for builtin pickers
					pickers = {
						buffers = {
							mappings = { [{ "n" }] = { ["dd"] = A.delete_buffer } },
						},
						marks = {
							mappings = { [{ "n" }] = { ["dd"] = A.delete_mark } },
						},
						live_grep = {
							mappings = { [{ "n" }] = { ["cr"] = A.to_fuzzy_refine } },
						},
						grep_string = {
							mappings = { [{ "n" }] = { ["cr"] = A.to_fuzzy_refine } },
						},
						find_files = {
							hidden = true,
							no_ignore = false, -- show files ignored by `.gitignore,` `.ignore,` etc.
						},
						git_stash = {
							mappings = {
								[{ "n" }] = { ["gp"] = user_action.git_pop_stash },
								[{ "n" }] = { ["gd"] = user_action.git_drop_stash },
							},
						},
					},
				})

				api.nvim_create_autocmd("User", {
					pattern = "TelescopePreviewerLoaded",
					command = "setlocal number",
				})

				set_hls({ TelescopeBorder = { link = "FloatBorder" } })
			end,
		},
		-- }}}

		-- navigation {{{
		{
			"ThePrimeagen/harpoon",
			enabled = false,
			branch = "harpoon2",
			lazy = true,
			dependencies = { "plenary.nvim" },
			keys = {
				"<leader>A", -- Add
				"<leader>h", -- prev
				"<leader>l", -- next
				"<leader>E", -- mEnu
				"<leader>D", -- Delete
			},
			config = function(self, opts)
				vim.g.harpoon_enable_statusline = true

				local harpoon = require("harpoon")
				harpoon:setup({
					settings = {
						save_on_toggle = true,
						sync_on_ui_close = false,
					},
				})
				require("harpoon.config").DEFAULT_LIST = "files"

				local keys = self.keys or {}
				keymap.set("n", keys[1], function()
					harpoon:list():add()
				end)
				keymap.set("n", keys[2], function()
					if vim.v.count > 0 then
						harpoon:list():select(vim.v.count)
						return
					end
					harpoon:list():prev()
				end)
				keymap.set("n", keys[3], function()
					if vim.v.count > 0 then
						harpoon:list():select(vim.v.count)
						return
					end
					harpoon:list():next()
				end)
				keymap.set("n", keys[4], function()
					harpoon.ui:toggle_quick_menu(harpoon:list())
				end)
				keymap.set("n", keys[5], function()
					harpoon:list():remove()
				end)

				harpoon:extend({
					ADD = function(cx)
						local file = cx.item.value
						print(string.format("Harpoon add `%s`", file))
					end,
					REMOVE = function(cx)
						local file = cx.item.value
						print(string.format("Harpoon remove `%s`", file))
					end,
					UI_CREATE = function(cx)
						local win = cx.win_id
						local buf = cx.bufnr

						require("liu.utils.win").win_update_config(win, function(config)
							config.footer = harpoon.ui.active_list.name
							config.footer_pos = "right"

							config.width = math.floor(math.max(math.min(120, vim.o.columns / 2), 40))
							config.col = math.floor(vim.o.columns / 2 - config.width / 2)
							config.row = math.floor(vim.o.lines / 2 - config.height / 2)
						end)

						open_maps(buf, function()
							harpoon.ui:select_menu_item({ vsplit = true })
						end, function()
							harpoon.ui:select_menu_item({ split = true })
						end, function()
							harpoon.ui:select_menu_item({ tabedit = true })
						end)

						-- navigate with number
						for i = 1, 9 do
							vim.keymap.set("n", "" .. i, function()
								harpoon:list():select(i)
							end, { buffer = buf })
						end
					end,
				})
			end,
		},
		{
			"cbochs/grapple.nvim",
			opts = {
				-- scope = "git", -- also try out "git_branch"
				icons = true, -- setting to "true" requires "nvim-web-devicons"
				status = true,
				win_opts = {
					width = 0.4,
					height = 0.3,
					row = 0.5,
					col = 0.5,

					relative = "editor",
					border = config.borders,
					focusable = false,
					style = "minimal",
					title_pos = "center",

					-- Custom: fallback title for Grapple windows
					title = "Grapple",
					-- Custom: adds padding around window title
					title_padding = " ",
				},
			},
			cmd = "Grapple",
			keys = {
				{ "<leader>A", "<cmd>Grapple tag<cr>", desc = "Tag a file" },
				{ "<leader>D", "<cmd>Grapple untag<cr>", desc = "Untag a file" },
				{ "<leader>E", "<cmd>Grapple toggle_tags<cr>", desc = "Toggle tags menu" },
				{ "<leader>l", "<cmd>Grapple cycle_tags next<cr>", desc = "Go to next tag" },
				{ "<leader>h", "<cmd>Grapple cycle_tags prev<cr>", desc = "Go to previous tag" },
			},
		},
		{
			"echasnovski/mini.files",
			lazy = true,
			init = function()
				local g = liu_augroup("mini_files")
				autocmd("User", {
					pattern = "MiniFilesWindowOpen",
					group = g,
					callback = function(args)
						local win_id = args.data.win_id
						-- Customize window-local settings
						-- vim.wo[win_id].winblend = 50
						api.nvim_win_set_config(win_id, { border = config.borders })
					end,
				})

				local function split_rhs(modify)
					local minifiles = require("mini.files")

					local entry = minifiles.get_fs_entry()
					if entry.fs_type == "directory" then
						-- Noop if the explorer isn't open or the cursor is on a directory.
						print("no support on directory.")
						return
					end

					local root = minifiles.get_latest_path()
					local path = require("plenary.path"):new(entry.path):make_relative(root)
					vim.cmd(modify .. " " .. path)
					minifiles.close()
				end

				local yank_relative_path = function()
					-- local fn = vim.fn
					local minifiles = require("mini.files")
					local path = minifiles.get_fs_entry().path
					local p = fn.fnamemodify(path, ":.")
					fn.setreg(vim.v.register, p)
					print(string.format([["%s"]], p))
				end

				local add2harpoon = function(buf)
					local api = vim.api

					local minifiles = require("mini.files")
					local append2list = function(file)
						if file then
							local root = minifiles.get_latest_path()
							local Path = require("plenary.path")
							local list = require("harpoon"):list()
							list:add({
								value = Path:new(file.path):make_relative(root),
								context = { row = 1, col = 1 },
							})
						end
					end

					return function()
						local mode = vim.fn.mode()
						if mode == "n" then
							local win = api.nvim_get_current_win()
							local cursor = api.nvim_win_get_cursor(win)
							local file = minifiles.get_fs_entry(buf, cursor[1])
							append2list(file)
						elseif mode == "v" or mode == "V" then
							vim.cmd.normal(vim.keycode("<Esc>"))

							local start = api.nvim_buf_get_mark(0, "<")[1]
							local finish = api.nvim_buf_get_mark(0, ">")[1]
							for i = start, finish do
								local file = minifiles.get_fs_entry(buf, i)
								append2list(file)
							end
						end
					end
				end

				autocmd("User", {
					pattern = "MiniFilesBufferCreate",
					group = g,
					callback = function(args)
						local buf = args.data.buf_id

						local MiniFiles = require("mini.files")

						-- do
						-- 	-- https://github.com/echasnovski/mini.nvim/issues/391
						-- 	-- set up ability to confirm changes with :w
						-- 	api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
						-- 	api.nvim_buf_set_name(buf, string.format("mini.files-%s", uv.hrtime()))
						-- 	api.nvim_create_autocmd("BufWriteCmd", {
						-- 		callback = MiniFiles.synchronize,
						-- 		buffer = buf,
						-- 	})
						-- end

						keymap.set("n", "<CR>", function()
							MiniFiles.go_in({ close_on_file = true })
						end, { buffer = buf })
						keymap.set("n", "<leader><CR>", MiniFiles.synchronize, { buffer = buf })

						open_maps(buf, function()
							split_rhs("split")
						end, function()
							split_rhs("vsplit")
						end, function()
							split_rhs("tabedit")
						end)

						keymap.set({ "n", "v" }, "<Tab>", add2harpoon(buf), { buffer = buf })

						keymap.set("n", "y<C-g>", yank_relative_path, { buffer = buf })
					end,
				})

				autocmd("User", {
					pattern = "MiniFilesActionDelete",
					group = g,
					callback = function(args)
						local fname = args.data.from
						local bufnr = fn.bufnr(fname)
						if bufnr > 0 then
							-- delete buffer
							require("mini.bufremove").delete(bufnr, false)
						end
					end,
				})
			end,
			keys = {
				{
					"<leader>e",
					function()
						local MiniFiles = require("mini.files")
						if not MiniFiles.close() then
							local bufname = api.nvim_buf_get_name(0)
							local path = fn.fnamemodify(bufname, ":p")
							-- Open last if the buffer isn't valid.
							---@diagnostic disable-next-line: undefined-field
							if path and uv.fs_stat(path) then
								MiniFiles.open(bufname, false)
							else
								MiniFiles.open(MiniFiles.get_latest_path())
							end
						end
					end,
					desc = "File [E]xplorer",
				},
			},
			opts = {
				mappings = {
					go_in = "<C-l>",
					go_out = "<C-h>",
					-- Use `''` (empty string) to not create one.
					go_in_plus = "",
					go_out_plus = "",
				},
				options = {
					use_as_default_explorer = false,
				},
			},
		},
		-- }}}

		-- motion(text object) {{{2
		{
			"folke/flash.nvim",
			keys = {
				{
					"<leader>f",
					mode = { "n", "o", "x" },
					function()
						require("flash").jump()
					end,
					desc = "Flash",
				},
			},
			opts = {
				modes = {
					search = { enabled = false },
					char = { enabled = false },
				},
				prompt = {
					-- Place the prompt above the statusline.
					win_config = { row = -3 },
				},
			},
			config = function(_, opts)
				require("flash").setup(opts)

				set_hls({
					FlashBackdrop = { fg = config.colors.gray },
				})
			end,
		},
		{
			"echasnovski/mini.ai",
			keys = function(self, _)
				local keys = {
					{ "i", mode = { "o", "x" } },
					{ "a", mode = { "o", "x" } },
					"g[",
					"g]",
				}
				local map_start = function(op, ai)
					table.insert(keys, {
						"]" .. op,
						function()
							require("mini.ai").move_cursor("left", ai, op, { search_method = "next" })
						end,
						desc = "Goto next start of " .. ai .. op .. " textobject",
					})
					table.insert(keys, {
						"[" .. op,
						function()
							require("mini.ai").move_cursor("left", ai, op, { search_method = "cover_or_prev" })
						end,
						desc = "Goto previous start of " .. ai .. op .. " textobject",
					})
				end
				local map_end = function(op, ai)
					table.insert(keys, {
						"]" .. op:upper(),
						function()
							require("mini.ai").move_cursor("right", ai, op, { search_method = "cover_or_next" })
						end,
						desc = "Goto next end of " .. ai .. op .. " textobject",
					})
					table.insert(keys, {
						"[" .. op:upper(),
						function()
							require("mini.ai").move_cursor("right", ai, op, { search_method = "prev" })
						end,
						desc = "Goto previous end of " .. ai .. op .. " textobject",
					})
				end
				for _, op in pairs({ "f", "c" }) do
					map_start(op, "a")
					map_end(op, "a")
				end

				return keys
			end,
			config = function(self, opts)
				local ai = require("mini.ai")
				local ts_gen = ai.gen_spec.treesitter
				ai.setup({
					silent = true,
					-- search_method = "cover",
					n_lines = 300,
					custom_textobjects = {
						o = ts_gen({ a = { "@conditional.outer" }, i = { "@conditional.inner" } }, {}),
						f = ts_gen({ a = "@function.outer", i = "@function.inner" }, {}),
						c = ts_gen({ a = "@class.outer", i = "@class.inner" }, {}),
					},
					mappings = {
						-- -- Main textobject prefixes
						-- around = "a",
						-- inside = "i",

						-- -- Disable next variants.
						-- around_next = "",
						-- inside_next = "",

						-- Disable last variants.
						around_last = "",
						inside_last = "",

						-- Move cursor to corresponding edge of `a` textobject
						goto_left = "g[",
						goto_right = "g]",
					},
				})
			end,
		},
		{
			"chaoren/vim-wordmotion",
			enabled = true,
			init = function()
				vim.g.wordmotion_nomap = true
				vim.g.wordmotion_prefix = ","

				-- user defined
				vim.g.wordmotion_disable = true
			end,
			keys = {
				{
					"<leader>tw",
					function()
						local mod_nxo = { "n", "x", "o" }
						local mod_xo = { "x", "o" }
						vim.g.wordmotion_disable = not vim.g.wordmotion_disable
						if vim.g.wordmotion_disable then
							keymap.del(mod_nxo, "w")
							keymap.del(mod_nxo, "b")
							keymap.del(mod_nxo, "e")
							keymap.del(mod_xo, "iw")
							keymap.del(mod_xo, "aw")

							vim.notify("Disabled word motion", vim.log.levels.WARN)
						else
							keymap.set(mod_nxo, "w", "<Plug>WordMotion_w")
							keymap.set(mod_nxo, "b", "<Plug>WordMotion_b")
							keymap.set(mod_nxo, "e", "<Plug>WordMotion_e")
							keymap.set(mod_xo, "iw", "<Plug>WordMotion_iw")
							keymap.set(mod_xo, "aw", "<Plug>WordMotion_aw")

							vim.notify("Enabled word motion", vim.log.levels.WARN)
						end
					end,
					desc = "[T]oggle [W]ord motion",
				},
			},
		},
		-- }}}

		-- completion {{{2
		{
			"hrsh7th/nvim-cmp",
			event = {
				"InsertEnter",
				-- "CmdlineEnter",
			},
			dependencies = {
				"hrsh7th/cmp-path",
				"hrsh7th/cmp-buffer",
				"hrsh7th/cmp-nvim-lsp",
				"hrsh7th/cmp-nvim-lsp-signature-help",
				-- "hrsh7th/cmp-omni",
				"gh-liu/cmp-omni", -- #10
			},
			config = function()
				local luasnip = require("luasnip")

				local cmp = require("cmp")

				local function has_words_before()
					local line, col = unpack(api.nvim_win_get_cursor(0))
					return (
						(col ~= 0)
						and (((api.nvim_buf_get_lines(0, (line - 1), line, true))[1]):sub(col, col):match("%s") == nil)
					)
				end

				local winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"

				---@diagnostic disable-next-line: missing-fields
				cmp.setup({
					snippet = {
						expand = function(args)
							luasnip.lsp_expand(args.body) -- For `luasnip` users.
						end,
					},
					mapping = cmp.mapping.preset.insert({
						["<C-b>"] = cmp.mapping.scroll_docs(-4),
						["<C-f>"] = cmp.mapping.scroll_docs(4),

						["<CR>"] = cmp.mapping.confirm({
							behavior = cmp.ConfirmBehavior.Replace,
							select = true,
						}),
						["<C-e>"] = cmp.mapping.abort(),

						["<Tab>"] = cmp.mapping(function(fallback)
							if cmp.visible() then
								return cmp.select_next_item()
							elseif has_words_before() then
								return cmp.complete()
							else
								return fallback()
							end
						end, { "i" }),
						["<S-Tab>"] = cmp.mapping(function(fallback)
							if cmp.visible() then
								return cmp.select_prev_item()
							else
								return fallback()
							end
						end, { "i" }),

						-- luasnip choice
						["<C-j>"] = cmp.mapping(function(fallback)
							if luasnip.choice_active() then
								return luasnip.change_choice(1)
							else
								return fallback()
							end
						end, { "i", "s" }),
						["<c-k>"] = cmp.mapping(function(fallback)
							if luasnip.choice_active() then
								return luasnip.change_choice(-1)
							else
								return fallback()
							end
						end, { "i", "s" }),
						-- luaship snippet jump
						["<C-h>"] = cmp.mapping(function(fallback)
							if luasnip.in_snippet() and luasnip.jumpable(-1) then
								return luasnip.jump(-1)
							else
								return fallback()
							end
						end, { "i", "s" }),
						["<C-l>"] = cmp.mapping(function(fallback)
							if luasnip.in_snippet() and luasnip.jumpable(1) then
								return luasnip.jump(1)
							else
								return fallback()
							end
						end, { "i", "s" }),
					}),
					view = {
						entries = { follow_cursor = true },
					},
					window = {
						completion = {
							border = config.borders,
							winhighlight = winhighlight,
						},
						documentation = {
							border = config.borders,
							winhighlight = winhighlight,
							max_height = math.floor(vim.o.lines * 0.5),
							max_width = math.floor(vim.o.columns * 0.4),
						},
					},
					sources = {
						{ name = "nvim_lsp" },
						{ name = "nvim_lsp_signature_help" },
						{
							name = "buffer",
							keyword_length = 3,
							option = {
								get_bufnrs = function()
									local bufs = {}
									for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
										table.insert(bufs, api.nvim_win_get_buf(win))
									end
									return bufs
								end,
							},
						},
						{ name = "path" },
						{ name = "luasnip" },
					},
					formatting = {
						fields = { "abbr", "kind", "menu" },
						format = function(entry, item)
							local kind = item.kind
							local symbol = (config.icons.completion_item_kinds)[kind]
							if symbol then
								item.kind = symbol.icon .. kind
								item.kind_hl_group = symbol.hl
							end

							local source_labels = {
								buffer = "[BUF]",
								nvim_lsp = "[LSP]", -- unknown source https://github.com/hrsh7th/nvim-cmp/issues/290#issuecomment-939327970
								luasnip = "[SNIP]",
								path = "[PATH]",
								omni = "[OMNI]",
								git = "[GIT]",
							}
							item.menu = (source_labels[entry.source.name] or "")
							return item
						end,
					},
				})

				-- ft: query
				cmp.setup.filetype({ "query" }, {
					sources = cmp.config.sources({
						{ name = "omni" },
					}),
				})

				local highlights = {}
				for key, value in pairs(config.icons.completion_item_kinds) do
					highlights["CmpItemKind" .. key] = { link = value.hl }
				end
				set_hls(highlights)
			end,
		},
		{
			"petertriho/cmp-git",
			cond = function()
				return fn.executable("git") == 1
			end,
			ft = {
				"gitcommit",
				"octo",
			},
			config = function(self, opts)
				require("cmp_git").setup({
					filetypes = self.ft,
				})

				local cmp = require("cmp")
				cmp.setup.filetype(self.ft, {
					sources = {
						{ name = "git" },
						{ name = "buffer" },
						{ name = "luasnip" },
					},
				})
			end,
		},
		{
			"rcarriga/cmp-dap",
			ft = {
				"dap-repl",
				"dapui_watches",
				"dapui_hover",
			},
			config = function(self, opts)
				local cmp = require("cmp")
				cmp.setup.filetype({ "dap-repl" }, {
					enabled = true,
					sources = { { name = "omni" }, { name = "dap" } },
				})
				cmp.setup.filetype({ "dapui_watches", "dapui_hover" }, {
					enabled = true,
					sources = { { name = "dap" } },
				})
			end,
		},
		{
			"L3MON4D3/LuaSnip",
			lazy = true,
			build = "make install_jsregexp", -- https://github.com/L3MON4D3/LuaSnip/blob/master/DOC.md#transformations
			dependencies = {
				"rafamadriz/friendly-snippets",
				"saadparwaiz1/cmp_luasnip",
			},
			config = function(self, opts)
				local types = require("luasnip.util.types")

				local luasnip = require("luasnip")
				luasnip.config.setup({
					keep_roots = false,
					link_roots = false,
					link_children = true,
					update_events = { "InsertLeave" },
					region_check_events = { "InsertEnter" },
					delete_check_events = { "TextChanged" },
					-- store_selection_keys = "<Tab>",
					enable_autosnippets = false,
					ext_opts = {
						[types.choiceNode] = {
							passive = {
								virt_text = { { " ⇦ ", "LuasnipChoiceNodePassive" } },
								virt_text_pos = "inline",
							},
							active = {
								virt_text = { { " ⬅ ", "LuasnipChoiceNodeActive" } },
								virt_text_pos = "inline",
							},
						},
						[types.insertNode] = {
							unvisited = {
								virt_text = { { "|", "LuasnipChoiceNodeUnvisited" } },
								virt_text_pos = "inline",
							},
						},
						[types.exitNode] = {
							unvisited = {
								virt_text = { { "|", "LuasnipExitNodeUnvisited" } },
								virt_text_pos = "inline",
							},
						},
					},
				})

				require("luasnip.loaders.from_lua").load({
					paths = (vim.fn.stdpath("config") .. "/snippets/luasnip"),
				})
				require("luasnip.loaders.from_vscode").lazy_load()

				api.nvim_create_user_command("LuaSnipEdit", function()
					require("luasnip.loaders").edit_snippet_files({})
				end, { nargs = 0 })

				api.nvim_create_autocmd("ModeChanged", {
					group = liu_augroup("unlink_snippet"),
					desc = "Cancel the snippet session when leaving insert mode",
					pattern = { "s:n", "i:*" },
					callback = function(args)
						if
							luasnip.session
							and luasnip.session.current_nodes[args.buf]
							and not luasnip.session.jump_active
							and not luasnip.choice_active()
						then
							luasnip.unlink_current()
						end
					end,
				})

				set_hls({
					LuasnipInsertNodeActive = {
						fg = config.colors.green,
					},
					LuasnipInsertNodePassive = {
						fg = config.colors.blue,
					},
					LuasnipChoiceNodeActive = {
						fg = config.colors.red,
					},
					LuasnipChoiceNodePassive = {
						fg = config.colors.blue,
					},
					LuasnipChoiceNodeUnvisited = {
						fg = config.colors.gray,
						italic = true,
					},
					LuasnipExitNodeUnvisited = {
						fg = config.colors.gray,
						bold = true,
					},
				})
			end,
		},
		{
			"echasnovski/mini.pairs",
			event = "InsertEnter",
			init = function(self)
				vim.g.minipairs_disable = false
			end,
			keys = {
				{
					"<leader>tp",
					function()
						vim.g.minipairs_disable = not vim.g.minipairs_disable
						if vim.g.minipairs_disable then
							vim.notify("Disabled auto pairs", vim.log.levels.WARN)
						else
							vim.notify("Enabled auto pairs", vim.log.levels.WARN)
						end

						-- When a bracket is inserted, briefly jump to the matching one.
						vim.o.showmatch = vim.g.minipairs_disable
					end,
					desc = "[T]oggle auto [P]airs",
				},
			},
			config = function(self, opts)
				local pairs = require("mini.pairs")
				pairs.setup()

				local pairs_by_fts = {
					zig = function(buf)
						pairs.map_buf(buf, "i", "|", { action = "closeopen", pair = "||", register = { cr = false } })
					end,
					rust = function(buf)
						pairs.map_buf(buf, "i", "|", { action = "closeopen", pair = "||", register = { cr = false } })
						pairs.map_buf(buf, "i", "<", { action = "open", pair = "<>", register = { cr = false } })
						pairs.map_buf(buf, "i", ">", { action = "close", pair = "<>", register = { cr = false } })
					end,
				}

				autocmd("FileType", {
					group = liu_augroup("mini_pairs"),
					pattern = vim.tbl_keys(pairs_by_fts),
					callback = function(ev)
						local buf = ev.buf
						pairs_by_fts[ev.match](buf)
					end,
					desc = "set mini pairs for fts",
				})
			end,
		},
		-- }}}

		-- git {{{2
		{
			"tpope/vim-fugitive",
			event = "VeryLazy",
			dependencies = {
				"tpope/vim-rhubarb",
			},
			config = function()
				load_plugin_config("git")
			end,
		},
		{
			"rbong/vim-flog",
			init = function(self)
				vim.g.flog_use_internal_lua = 1
				vim.g.flog_default_opts = { max_count = 2000 }
				vim.g.flog_permanent_default_opts = { date = "format:%Y-%m-%d %H:%m" }

				-- keymap.set("ca", "F", "Flog", {})
				keymap.set("ca", "F", "Flogsplit", {})

				autocmd("FileType", {
					pattern = "floggraph",
					callback = function(ev)
						local buf = ev.buf
						local nmap = function(lhs, rhs, opts)
							opts = opts or { buffer = buf, silent = true }
							keymap.set("n", lhs, rhs, opts)
						end

						-- like fugitive
						nmap("o", "<Plug>(FlogVSplitCommitRight)")

						nmap("q", "<cmd>normal gq<cr>")

						-- git absorb
						nmap("gaa", ":Floggit absorb<space>", { buffer = buf })
						-- :flog-%h
						-- The hash of the commit under the cursor, if any.
						nmap("gab", "<cmd><C-U>exec flog#Format('Floggit absorb --base %h')<CR>")
						nmap("gar", "<cmd><C-U>exec flog#Format('Floggit absorb --base %h --and-rebase')<CR>")
					end,
				})
			end,
			cmd = {
				"Flog",
				"Flogsplit",
				"Floggit",
			},
			config = function(self, opts)
				set_hls({
					flogBranch1 = { fg = config.colors.yellow },
					flogBranch2 = { fg = config.colors.blue },
					flogBranch3 = { fg = config.colors.green },
					flogBranch4 = { fg = config.colors.red },
					flogBranch5 = { fg = config.colors.magenta },
					flogBranch6 = { fg = config.colors.gray },
					flogBranch7 = { fg = config.colors.orange },
					flogBranch8 = { fg = config.colors.cyan },
					-- flogBranch9 = { fg = config.colors.green },
				})
			end,
		},
		{
			"echasnovski/mini.diff",
			event = "VeryLazy",
			opts = {
				view = {
					-- Visualization style. Possible values are 'sign' and 'number'.
					style = vim.go.number and "number" or "sign",
					-- Signs used for hunks with 'sign' view
					signs = { add = "▒", change = "▒", delete = "▒" },
					-- Priority of used visualization extmarks
					priority = vim.highlight.priorities.user - 1,
				},
				-- Source for how reference text is computed/updated/etc
				-- Uses content from Git index by default
				source = nil,
				-- Delays (in ms) defining asynchronous processes
				delay = {
					-- How much to wait before update following every text change
					text_change = 200,
				},
				-- Module mappings. Use `''` (empty string) to disable one.
				-- mappings = {
				-- 	-- Apply hunks inside a visual/operator region
				-- 	apply = "gh", -- WRITE TO DIFF SOURCE
				-- 	-- Reset hunks inside a visual/operator region
				-- 	reset = "gH", -- READ FROM DIFF SOURCE
				-- 	-- Hunk range textobject to be used inside operator
				-- 	textobject = "gh",
				-- 	-- Go to hunk range in corresponding direction
				-- 	goto_first = "[H",
				-- 	goto_prev = "[h",
				-- 	goto_next = "]h",
				-- 	goto_last = "]H",
				-- },
				-- Various options
				options = {
					-- Diff algorithm. See `:h vim.diff()`.
					algorithm = "histogram",
					-- Whether to use "indent heuristic". See `:h vim.diff()`.
					indent_heuristic = true,
					-- The amount of second-stage diff to align lines (in Neovim>=0.9)
					linematch = 60,
				},
			},
			config = function(self, opts)
				require("mini.diff").setup(opts)

				local MiniDiff = require("mini.diff")
				set_cmds({
					DiffOverlay = function()
						MiniDiff.toggle_overlay()
					end,
					DiffHunks = function(opts)
						local export_opts = { scope = "current" }
						if opts.bang then
							export_opts.scope = "all"
						end
						vim.fn.setqflist(MiniDiff.export("qf", export_opts))
						vim.cmd.copen()
					end,
				})
			end,
		},
		{
			"pwntester/octo.nvim",
			enabled = false,
			cond = function()
				return fn.executable("gh") == 1
			end,
			cmd = { "Octo" },
			config = function(_, opts)
				require("octo").setup({
					enable_builtin = true,
					timeout = 3000,
				})

				vim.treesitter.language.register("markdown", "octo")
			end,
		},
		-- }}}

		-- improvement {{{2
		{
			"mbbill/undotree",
			init = function()
				vim.g.undotree_WindowLayout = 2
				vim.g.undotree_DiffAutoOpen = 1
				vim.g.undotree_ShortIndicators = 1
				vim.g.undotree_SetFocusWhenToggle = 1
			end,
			keys = {
				{
					"<leader>tu",
					vim.cmd.UndotreeToggle,
					desc = "Undotree: Toggle",
					noremap = true,
					silent = true,
				},
			},
			cmd = { "UndotreeToggle" },
		},
		{
			"echasnovski/mini.bufremove",
			lazy = true,
			cmd = { "Bdelete", "Bwipeout" },
			keys = {
				{
					"<leader>bd",
					function()
						require("mini.bufremove").delete(0, false)
					end,
					desc = "Delete Buffer",
				},
			},
			opts = {},
			config = function(self, opts)
				local MiniBufremove = require("mini.bufremove")
				MiniBufremove.setup(self.opts)

				local cmd_opts = {
					bang = true,
					addr = "buffers",
					nargs = "?",
					complete = "buffer",
				}
				local buf_id = function(opts)
					local buffer = 0
					if #opts.fargs == 1 then
						local bufnr = fn.bufnr(opts.fargs[1])
						if bufnr > 0 then
							buffer = bufnr
						end
					end
					return buffer
				end
				api.nvim_create_user_command("Bdelete", function(opts)
					MiniBufremove.delete(buf_id(opts), opts.bang)
				end, cmd_opts)
				api.nvim_create_user_command("Bwipeout", function(opts)
					MiniBufremove.wipeout(buf_id(opts), opts.bang)
				end, cmd_opts)
			end,
		},
		-- }}}

		-- filetype specifically {{{2
		{
			"saecki/crates.nvim",
			enabled = false,
			lazy = true,
			event = { "BufRead Cargo.toml" },
			config = function()
				require("crates").setup({
					popup = {
						border = config.borders,
					},
					src = {},
					lsp = {
						enabled = true,
						name = "crates.nvim",
						-- on_attach = function(client, bufnr) end,
						actions = true,
						completion = true,
					},
				})
			end,
		},
		{
			"fladson/vim-kitty",
			ft = "kitty",
		},
		{
			"zchee/vim-goasm",
			ft = "goasm",
		},
		{
			"ellisonleao/glow.nvim",
			cond = function()
				return fn.executable("glow") == 1
			end,
			enabled = true,
			opts = {
				border = config.borders,
				-- width_ratio = 0.8,
				-- height_ratio = 0.8,
			},
			cmd = "Glow",
		},
		-- }}}

		-- tpope {{{2
		{
			"tpope/vim-repeat",
			event = "VeryLazy",
		},
		{
			"tpope/vim-rsi",
			init = function(self)
				vim.g.rsi_no_meta = 1
			end,
			event = { "InsertEnter", "CmdlineEnter" },
		},
		{
			"tpope/vim-eunuch",
			enabled = false,
			cmd = {
				"SudoEdit",
				"SudoWrite",
				"Remove",
				"Delete",
				"Copy",
				"Move",
				"Chmod",
				"Mkdir",
				"W",
				"Wall",
				"Cfind",
				"Lfind",
			},
		},
		{
			"tpope/vim-sleuth",
			event = "VeryLazy",
		},
		{
			"tpope/vim-unimpaired",
			init = function(self)
				paire_move.setkeymap("l", { next = "]l", prev = "[l" })
				paire_move.setkeymap("q", { next = "]q", prev = "[q" })
			end,
			keys = { "yo", "[", "]" },
			config = function(self, opts)
				vim.keymap.set(
					"n",
					"yoz",
					[[&foldmethod ==# 'syntax' ? ':setlocal foldmethod=manual<CR>' : ':setlocal foldmethod=syntax<CR>']],
					{ expr = true }
				)

				vim.keymap.set(
					"n",
					"yof",
					[[&winfixbuf ? ':setlocal nowinfixbuf<CR>' : ':setlocal winfixbuf<CR>']],
					{ expr = true }
				)
			end,
		},
		{
			"tpope/vim-dispatch",
			init = function()
				vim.g.dispatch_no_maps = 1
			end,
			cmd = {
				"Make",
				"Dispatch",
				"Start",
			},
		},
		{
			"tpope/vim-obsession",
			cmd = { "Obsession" },
		},
		{
			"tpope/vim-projectionist",
			lazy = true,
			-- event = "VeryLazy",
			init = function(self)
				---@diagnostic disable-next-line: undefined-field
				local cwd = uv.cwd()
				if fn.filereadable(cwd .. "/.projections.json") == 1 then
					require("lazy").load({ plugins = { "vim-projectionist" } })
				end

				local go_main_template = "package main"
				vim.g.projectionist_heuristics = {
					["go.mod"] = {
						["README.md"] = { type = "doc" },
						["go.mod"] = { type = "dep" },
						["*.go&!*_test.go"] = {
							alternate = "{}_test.go",
							-- related = "{}_test.go",
							type = "source",
							template = [[package {file|dirname|basename}]],
						},
						["*_test.go"] = {
							alternate = "{}.go",
							-- related = "{}.go",
							type = "test",
							template = [[package {file|dirname|basename}_test]],
						},
						["cmd/*/main.go"] = {
							type = "main", -- argument will replace the glob
							template = go_main_template,
							dispatch = "go run {file|dirname}",
							start = "go run {file|dirname}",
							make = "go build {file|dirname}",
						},
						["main.go"] = {
							-- If this option is provided for a literal filename rather than a glob,
							-- it is used as the default destination of the navigation command when no argument is given.
							type = "main",
							template = go_main_template,
							dispatch = "go run {file|dirname}",
							start = "go run {file|dirname}",
							make = "go build {file|dirname}",
						},
					},
					["build.zig"] = {
						["README.md"] = { type = "doc" },
						["build.zig"] = {
							type = "build",
							alternate = "build.zig.zon",
						},
						["build.zig.zon"] = {
							type = "dep",
							alternate = "build.zig",
						},
						["src/main.zig"] = {
							type = "main",
							template = [[pub fn main() !void {|open}{|close}]],
						},
					},
				}

				-- autocmd("User", {
				-- 	pattern = "ProjectionistDetect",
				-- 	callback = function(ev)
				-- 		vim.notify("[Projections] detect!", vim.log.levels.INFO)
				-- 		vim.print(vim.g.projectionist_file)
				-- 	end,
				-- })

				-- autocmd("User", {
				-- 	pattern = "ProjectionistActivate",
				-- 	callback = function(ev)
				-- 		-- property can be defined
				-- 		-- [root, property_value]
				-- 		fn["projectionist#query"]("property")
				-- 	end,
				-- })
			end,
			ft = {
				"go",
				"zig",
			},
			keys = {
				{ "<leader>aa", "<cmd>A<cr>" },
				{ "<leader>av", "<cmd>AV<cr>" },
			},
		},
		-- }}}

		-- database {{{
		{
			"tpope/vim-dadbod",
			cmd = { "DB" },
			ft = { "sql", "mysql" },
			init = function(self)
				autocmd("FileType", {
					pattern = self.ft,
					callback = function(ev)
						vim.keymap.set({ "n", "x" }, "Q", "db#op_exec()", { expr = true, buffer = ev.buf })
					end,
					desc = "vim-dadbod `db#op_exec()`",
				})
			end,
		},
		{
			"kristijanhusak/vim-dadbod-ui",
			dependencies = { "tpope/vim-dadbod" },
			init = function()
				vim.g.db_ui_show_help = 0
				vim.g.db_ui_use_nerd_fonts = 1
				vim.g.db_ui_execute_on_save = 1
				vim.g.db_ui_force_echo_notifications = 1

				--  Five variables: `{table}`, `{schema}`, `{optional_schema}`, `{dbname}`, `{last_query}`
				vim.g.db_ui_table_helpers = {
					postgresql = {
						Count = "select count(*) from {optional_schema}{table}",
					},
					mysql = {
						Count = "select count(*) from {table}",
					},
				}
			end,
			cmd = {
				"DBUI",
				"DBUIToggle",
			},
			config = function(self, opts)
				-- :h vim-dadbod-ui-highlights
				set_hls({
					NotificationInfo = { link = "DiagnosticInfo" },
					NotificationWarning = { link = "DiagnosticWarn" },
					NotificationError = { link = "DiagnosticError" },
				})
			end,
		},

		-- }}}

		-- misc {{{2
		{
			"akinsho/toggleterm.nvim",
			enabled = false,
			keys = { [[<c-\>]] },
			opts = {
				on_open = function(t)
					vim.o.ch = 0
				end,
				on_close = function(t)
					vim.o.ch = 1
				end,
				highlights = {
					StatusLine = { link = "StatusLine" },
				},
				-- shades terminal to be darker than other window
				-- shade_terminals = false,
				shading_factor = "-6",
			},
			config = function(self, opts)
				opts.open_mapping = self.keys[1]
				require("toggleterm").setup(opts)
			end,
		},
		{
			"jbyuki/venn.nvim",
			enabled = true,
			lazy = true,
			cmd = { "ToggleVBox" },
			config = function(self, opts)
				local function toggle_venn()
					local api = vim.api
					if not vim.b.venn_enabled then
						vim.b.venn_enabled = true
						print("venn enabled")

						vim.cmd([[setlocal ve=all]])

						-- draw a line on HJKL keystokes
						vim.keymap.set("n", "H", "<C-v>h:VBox<CR>", { buffer = 0, noremap = true })
						vim.keymap.set("n", "J", "<C-v>j:VBox<CR>", { buffer = 0, noremap = true })
						vim.keymap.set("n", "K", "<C-v>k:VBox<CR>", { buffer = 0, noremap = true })
						vim.keymap.set("n", "L", "<C-v>l:VBox<CR>", { buffer = 0, noremap = true })
					else
						vim.b.venn_enabled = false
						print("venn disabled")

						vim.cmd([[setlocal ve=]])

						vim.keymap.del("n", "H", { buffer = 0 })
						vim.keymap.del("n", "J", { buffer = 0 })
						vim.keymap.del("n", "K", { buffer = 0 })
						vim.keymap.del("n", "L", { buffer = 0 })
					end
				end

				create_command(self.cmd[1], function(opts)
					toggle_venn()
				end, { nargs = 0 })
			end,
		},
		{
			"NvChad/nvim-colorizer.lua",
			opts = {},
			cmd = "ColorizerToggle",
		},
		-- }}}
	},
	-- Lazy Configuration {{{2
	{
		performance = {
			rtp = {
				disabled_plugins = {
					"gzip",
					-- "matchit",
					-- "matchparen",
					"netrwPlugin",
					"tarPlugin",
					"tohtml",
					"tutor",
					"zipPlugin",
				},
			},
		},
		change_detection = {
			enabled = false,
			notify = false,
		},
		install = {
			missing = true,
			colorscheme = { vim.g.colors_name },
		},
		ui = {
			border = config.borders,
			backdrop = 90,
			-- icons = {
			-- 	cmd = "⌘",
			-- 	config = "🛠",
			-- 	event = "📅",
			-- 	ft = "📂",
			-- 	init = "⚙",
			-- 	keys = "🗝",
			-- 	plugin = "🔌",
			-- 	runtime = "💻",
			-- 	require = "🌙",
			-- 	source = "📄",
			-- 	start = "🚀",
			-- 	task = "📌",
			-- 	lazy = "💤 ",
			-- },
			icons = {
				cmd = " ",
				config = "",
				event = " ",
				ft = " ",
				init = " ",
				import = " ",
				keys = " ",
				lazy = "󰒲 ",
				loaded = "●",
				not_loaded = "○",
				plugin = " ",
				runtime = " ",
				require = "󰢱 ",
				source = " ",
				start = " ",
				task = "✔ ",
				list = {
					"●",
					"➜",
					"★",
					"‒",
				},
			},
		},
	}
	-- }}}
)
-- }}}

-- Sets {{{1
local opt_tbl2str = function(opts)
	return vim.iter(opts):join(",")
end
vim.o.mouse = ""
vim.o.clipboard = "unnamedplus"

vim.o.viewoptions = "folds,curdir"

vim.o.completeopt = "menu,menuone,noselect"

vim.o.confirm = true

vim.o.diffopt = opt_tbl2str({
	"internal",
	"filler",
	"closeoff",
	"hiddenoff", -- Do not use diff mode for a buffer when it becomes hidden.
	"algorithm:minimal",
	-- "linematch:60", -- https://github.com/neovim/neovim/pull/14537
})

-- UI {{{2
vim.o.termguicolors = true

vim.wo.number = true
vim.wo.relativenumber = true

vim.wo.signcolumn = "yes"

vim.o.laststatus = 3
vim.o.showmode = false
vim.o.showcmd = false

vim.o.pumheight = 12
vim.o.pumblend = 18

-- vim.o.scrolloff = 3

vim.o.cursorline = true

vim.o.splitright = true
vim.o.splitbelow = false

vim.cmd([[
	set guicursor=n-v:block,i-c-ci-ve:ver25,r-cr:hor20,o:hor50
	  \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
	  \,sm:block-blinkwait175-blinkoff150-blinkon175
]])

-- Avoid showing the intro when starting Neovim
vim.opt.shortmess:append("I")
-- }}}

-- Search {{{2
vim.o.hlsearch = false
vim.o.incsearch = true

vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.infercase = true

-- if fn.executable("rg") == 1 then
-- 	vim.o.grepprg = "rg --vimgrep --no-heading"
-- 	vim.o.grepformat = "%f:%l:%c:%m,%f:%l:%m"
-- end
-- }}}

-- Undo {{{2
vim.o.undofile = true
vim.o.undodir = os.getenv("HOME") .. "/.vim/undodir"
-- }}}

-- Time {{{2
vim.o.timeout = true
vim.o.timeoutlen = 350
vim.o.updatetime = 300
-- }}}

-- Wrap {{{2
vim.o.wrap = false
vim.o.whichwrap = "b,s,<,>,h,l"
-- }}}

-- Folding {{{2
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99

-- Filling `foldtext` with space
-- vim.opt.fillchars:append("fold: ")
vim.opt.fillchars:append("foldopen:" .. config.icons.fold[2])
vim.opt.fillchars:append("foldclose:" .. config.icons.fold[1])
-- vim.opt.fillchars:append("foldsep:|")
-- }}}

-- ShowMatch {{{2
vim.o.showmatch = false
vim.o.matchtime = 1
-- }}}

-- Listchars {{{2
-- vim.o.listchars = "tab:»,trail:-,nbsp:+,eol:↲"
vim.o.listchars = table.concat({
	"tab:» ",
	"trail:·",
	"nbsp:+",
	-- "space:␣",
	"eol:↲",
	-- "extends:<",
	-- "precedes:>",
}, ",")
-- }}}

autocmd("BufEnter", {
	group = liu_augroup("disable_newline_comment"),
	callback = function()
		vim.opt.formatoptions:remove({ "c", "r", "o" })
	end,
	desc = "Disable New Line Comment",
})
-- }}}

-- Remaps {{{1
local setmap = function(mode, lhs, rhs, opts)
	opts = opts or { silent = true, noremap = true }
	keymap.set(mode, lhs, rhs, opts)
end

-- Text {{{2
setmap("n", "Y", "y$")
setmap("x", "Y", "<ESC>y$gv")

-- lines move {{{3
-- use mini.move
-- setmap("x", "K", ":move '<-2<CR>gv=gv")
-- setmap("x", "J", ":move '>+1<CR>gv=gv")
-- setmap("x", "<", "<gv")
-- setmap("x", ">", ">gv")
-- }}}

-- changing a word, use dot do repeat {{{3
-- setmap("n", "cn", [[*``"_cgn]])
setmap("n", "cn", [[:normal "ryiw<CR> | :let @/=escape(@r, '/')<CR>"_cgn]])
-- changing a selection, use dot do repeat
-- "ry -- copy the selection to `r` register
-- let @/=escape(@r, '/') -- add the current selection from `r` register to the "search register"
-- "_ -- next operation store the text in the _ register
-- cgn -- replace the closest match to the search
-- setmap("x", "cn", [["ry<cmd>let @/=escape(@r, '/')<cr>"_cgn]])
-- use the substitute function to replace the newline character with \n
-- setmap("x", "cn", [[y<cmd>substitute(escape(@", '/'), '\n', '\\n', 'g')<cr>"_cgn]] )
-- }}}

-- append ;, at the eol {{{3
setmap("n", "<leader>g;", "mqA;<ESC>`q", { silent = true })
setmap("n", "<leader>g,", "mqA,<ESC>`q", { silent = true })
-- }}}

-- add undo break-points {{{3
setmap("i", ",", ",<c-g>u")
setmap("i", ";", ";<c-g>u")
setmap("i", ".", ".<c-g>u")
-- }}}

-- keep the old word in the clipboard
setmap("x", "p", '"_dP')
-- https://vim.fandom.com/wiki/Selecting_your_pasted_text
-- setmap("n", "vgp", [['`[' . strpart(getregtype(), 0, 1) . '`]']], { silent = true, expr = true })
setmap("n", "vgp", "`[v`]", { noremap = true })

-- }}}

-- Search {{{2
-- search in selected area
setmap("x", "/", "<Esc>/\\%V")
-- }}}

-- Exit {{{2
setmap("i", "jj", "<Esc>")
setmap("i", "kk", "<Esc>")

setmap("n", "<C-q>", ":quit<CR>")
-- }}}

-- Movement {{{2
-- HL as amplified versions of hl
setmap({ "n", "x", "o" }, "H", "^", { remap = true })
setmap({ "n", "x", "o" }, "L", "$")

-- Keep cursor in the center
setmap("n", "n", "nzzzv")
setmap("n", "N", "Nzzzv")
-- setmap("n", "<C-d>", "<C-d>zz")
-- setmap("n", "<C-u>", "<C-u>zz")
-- }}}

-- QF {{{2
setmap("n", "<leader>cc", "<cmd>try | cclose | lclose | catch | endtry <cr>")

-- setmap("n", "[q", "<cmd>try | cprev | catch | silent! clast | catch | endtry<cr>zv")
-- setmap("n", "]q", "<cmd>try | cnext | catch | silent! cfirst | catch | endtry<cr>zv")

-- setmap("n", "[l", ":lprev<cr>")
-- setmap("n", "]l", ":lnext<cr>")

-- }}}

-- Buffers {{{
-- setmap("n", "[b", "<cmd>bprevious<cr>")
-- setmap("n", "]b", "<cmd>bnext<cr>")

-- switch to alternate file
setmap("n", "<leader>bb", "<C-^>")
-- }}}

-- Tabs {{{2
setmap("n", "<C-w>O", ":tabonly<CR>")
setmap("n", "<C-w>Q", ":tabclose<CR>")
-- }}}

-- Abbrev{{{2
-- setmap("ca", "W", "((getcmdtype()  is# ':' && getcmdline() is# 'W')?('w'):('W'))", { expr = true })
setmap("ca", "Q", "((getcmdtype()  is# ':' && getcmdline() is# 'Q')?('q'):('Q'))", { expr = true })

setmap("ca", "%H", "expand('%:p:h')", { expr = true })
setmap("ca", "%P", "expand('%:p')", { expr = true })
setmap("ca", "%T", "expand('%:t')", { expr = true })

setmap("ca", "w'", "w", {})
-- }}}

-- File {{{2
-- cd to file parent
setmap("n", "<leader>cd", ":<C-U>cd %:h<CR>", { noremap = true })

-- go to parent dir
setmap("n", "<leader>cp", ":<C-U>cd ..<CR>", { noremap = true })

-- copy filename
-- setmap("n", "<leader>cf", ":<C-U>let @+ = expand('%:p')<CR>", { noremap = true })
-- setmap("n", "y<C-g>", ":<C-U>let @+ = expand('%:p')<CR>", { noremap = true })
-- }}}

setmap("s", "<BS>", [[<C-O>"_s]])

setmap("n", "z<space>", "za")

setmap("n", "<leader>w", "<cmd>write<cr>")

paire_move.setkeymap("c", { next = "]c", prev = "[c" })
-- }}}

-- Cmds {{{1
create_command("EditFtplugin", function(opts)
	local ft
	if #opts.fargs == 1 then
		ft = opts.fargs[1]
	else
		ft = vim.bo.ft
	end
	if ft == "" then
		return
	end

	local path = string.format("%s/after/ftplugin/%s.lua", fn.stdpath("config"), ft)
	vim.cmd.vsplit({ args = { path } })
end, {
	nargs = "?",
	desc = "Edit after ftplugin",
	complete = function()
		return fn.getcompletion("", "filetype")
	end,
})

--- Zoom in and out of a buffer, making it full screen in a floating window
---
--- This function is useful when working with multiple windows but temporarily
--- needing to zoom into one to see more of the code from that buffer. Call it
--- again (without arguments) to zoom out.
---
---@param buf_id number|nil Buffer identifier (see |bufnr()|) to be zoomed.
---   Default: 0 for current.
---@param config table|nil Optional config for window (as for |nvim_open_win()|).
local zoom = function(buf_id, config)
	if vim.t.zoom_winid and vim.api.nvim_win_is_valid(vim.t.zoom_winid) then
		vim.api.nvim_win_close(vim.t.zoom_winid, true)
		vim.t.zoom_winid = nil
	else
		buf_id = buf_id or 0
		-- Currently very big `width` and `height` get truncated to maximum allowed
		local default_config = { relative = "editor", row = 0, col = 0, width = 1000, height = 1000 }
		config = vim.tbl_deep_extend("force", default_config, config or {})
		vim.t.zoom_winid = vim.api.nvim_open_win(buf_id, true, config)
		vim.wo.winblend = 0
		vim.cmd("normal! zz")
	end
end
create_command("BufZoom", function(opts)
	zoom(0, nil)
end, {
	nargs = 0,
	desc = "Zoom in and out of a buffer, making it full screen in a floating window",
})

require("liu.utils.term").setup_cmd()

create_command("FindAndReplace", function(opts)
	if #opts.fargs ~= 2 then
		vim.print("Two argument required.")
	end
	api.nvim_command(string.format("silent cdo s/%s/%s", opts.fargs[1], opts.fargs[2]))
	api.nvim_command("silent cfdo update")
end, {
	nargs = "*",
	desc = "Find and Replace (after quickfix)",
})

create_command("R", function(opts)
	if #opts.fargs < 2 then
		vim.print("Arguments required.")
	end
	local old = fn.getreg("r")

	vim.cmd([[redir @r]])
	local cmd = table.concat(opts.fargs, " ")
	vim.cmd("silent " .. cmd)
	vim.cmd([[redir END]])

	vim.cmd([[vertical new | normal "rp]])

	fn.setreg("r", old)
end, {
	nargs = "*",
	desc = "Save the Output of Vim Command To a Empty Buffer",
})

create_command("AppendModeline", function(opts)
	local modeline = string.format(
		"vim: ts=%d sw=%d tw=%d %set :",
		vim.o.tabstop,
		vim.o.shiftwidth,
		vim.o.textwidth,
		vim.o.expandtab and "" or "no"
	)
	modeline = string.format(vim.bo.commentstring, modeline)
	api.nvim_buf_set_lines(0, -1, -1, false, { modeline })
	api.nvim_exec2("doautocmd BufRead", {})
end, {})

-- :h DiffOrig
create_command("DiffOrig", function()
	-- Get start buffer
	local start = api.nvim_get_current_buf()

	-- `vnew` - Create empty vertical split window
	-- `set buftype=nofile` - Buffer is not related to a file, will not be written
	-- `0d_` - Remove an extra empty start row
	-- `diffthis` - Set diff mode to a new vertical split
	vim.cmd("vnew | set buftype=nofile | read ++edit # | 0d_ | diffthis")

	-- Get scratch buffer
	local scratch = api.nvim_get_current_buf()

	-- some filetype
	vim.bo[scratch].ft = vim.bo[start].ft

	-- `wincmd p` - Go to the start window
	-- `diffthis` - Set diff mode to a start window
	vim.cmd("wincmd p | diffthis")
end, {})
-- }}}

-- Autocmds {{{1
local restore_cursor = function()
	-- Stop if not a normal buffer
	if vim.bo.buftype ~= "" then
		return
	end

	if vim.b.disable_restore_cursor then
		return
	end

	-- Stop if line is already specified (like during start with `nvim file +num`)
	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
	if cursor_line > 1 then
		return
	end

	-- Stop if can't restore proper line for some reason
	local mark_line = vim.api.nvim_buf_get_mark(0, [["]])[1]
	local n_lines = vim.api.nvim_buf_line_count(0)
	if not (1 <= mark_line and mark_line <= n_lines) then
		return
	end

	-- Restore cursor and
	vim.cmd([[normal! g`"]])
	-- Open just enough folds
	vim.cmd([[normal! zv]])

	-- Center window
	vim.cmd("normal! zz")
end
autocmd("BufReadPost", {
	desc = "Go to the last location when opening a buffer",
	group = liu_augroup("last_location"),
	callback = function(args)
		-- local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		-- local line_count = vim.api.nvim_buf_line_count(args.buf)
		-- if mark[1] > 0 and mark[1] <= line_count then
		-- 	vim.cmd('normal! g`"zz')
		-- end
		restore_cursor()
	end,
})

autocmd("VimResized", {
	desc = "Equalize Splits",
	group = liu_augroup("resize_splits"),
	command = "wincmd =",
})

autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
	desc = "Update file when there are changes",
	group = liu_augroup("checktime"),
	callback = function()
		-- normal buffer
		if vim.o.bt == "" then
			vim.cmd("checktime")
		end
	end,
})

autocmd("ModeChanged", {
	desc = "Highlighting matched words when searching",
	group = liu_augroup("switch_highlight_when_searching"),
	pattern = { "*:c", "c:*" },
	callback = function(ev)
		local cmdtype = fn.getcmdtype()
		if cmdtype == "/" or cmdtype == "?" then
			vim.opt.hlsearch = true
		else
			vim.opt.hlsearch = false
		end
	end,
})

autocmd("BufWinEnter", {
	desc = "Open help file in right split",
	group = liu_augroup("open_help_in_right_split"),
	pattern = { "*.txt" },
	callback = function(ev)
		if vim.o.filetype == "help" then
			vim.cmd.wincmd("L")
		end
	end,
})

autocmd({ "BufWritePre" }, {
	group = liu_augroup("auto_create_dir"),
	callback = function(event)
		if event.match:match("^%w%w+://") then
			return
		end
		---@diagnostic disable-next-line: undefined-field
		local file = uv.fs_realpath(event.match) or event.match
		fn.mkdir(fn.fnamemodify(file, ":p:h"), "p")
	end,
})

autocmd({ "TermOpen" }, {
	group = liu_augroup("term_map"),
	pattern = "term://*",
	callback = function(event)
		local opts = { buffer = event.buf }
		keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
		-- keymap.set("t", "jk", [[<C-\><C-n>]], opts)
		keymap.set("t", "jj", [[<C-\><C-n>]], opts)
		keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
		keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
		keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
		keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
		keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
	end,
})

autocmd("OptionSet", {
	desc = "OptionSetWrap",
	group = liu_augroup("option_set_wrap"),
	pattern = "wrap",
	callback = function(ev)
		local buffer = api.nvim_get_current_buf()
		if vim.v.option_new then
			keymap.set("n", "j", "gj", { buffer = buffer })
			keymap.set("n", "k", "gk")
		else
			pcall(keymap.del, "n", "j", { buffer = buffer })
			pcall(keymap.del, "n", "k", { buffer = buffer })
		end
	end,
})

autocmd("OptionSet", {
	desc = "turn off something when diff option toggle",
	group = liu_augroup("option_set_diff"),
	pattern = "diff",
	callback = function(ev)
		local bufnr = api.nvim_get_current_buf()
		local inlay_hint = lsp.inlay_hint

		local diff = vim.v.option_new
		if diff then
			local clients = vim.lsp.get_clients({ bufnr = bufnr, method = lsp.protocol.Methods.textDocument_inlayHint })
			if #clients > 0 and inlay_hint.is_enabled(bufnr) then
				inlay_hint.enable(false, { bufnr = bufnr })
			end

			vim.diagnostic.config({ signs = false })
		else
			local clients = vim.lsp.get_clients({ bufnr = bufnr, method = lsp.protocol.Methods.textDocument_inlayHint })
			if #clients > 0 and not inlay_hint.is_enabled(bufnr) then
				inlay_hint.enable(true, { bufnr = bufnr })
			end

			vim.diagnostic.config({ signs = true })
		end
	end,
})

local set_cursorline = liu_augroup("set_cursorline")
autocmd({ "InsertLeave" }, {
	desc = "set cursorline",
	group = set_cursorline,
	command = "set cursorline",
})
autocmd({ "InsertEnter" }, {
	desc = "set nocursorline",
	group = set_cursorline,
	command = "set nocursorline",
})

autocmd("CmdwinEnter", {
	desc = "cmdwin enter",
	group = liu_augroup("cmdwin_enter"),
	pattern = "*",
	callback = function()
		vim.wo.foldcolumn = "0"
		vim.wo.number = false
		vim.wo.relativenumber = false
		vim.wo.signcolumn = "no"
	end,
})
autocmd("BufHidden", {
	desc = "Delete [No Name] buffers",
	group = liu_augroup("delete_noname_buffers"),
	callback = function(data)
		if data.file == "" and vim.bo[data.buf].buftype == "" and not vim.bo[data.buf].modified then
			vim.schedule(function()
				pcall(api.nvim_buf_delete, data.buf, {})
			end)
		end
	end,
})
-- }}}

-- vim: foldmethod=marker
