-- Global Things {{{1
_G.config = {
	colors = {
		gray = "#616E88",
		green = "#A3BE8C",
		blue = "#5E81AC",
		cyan = "#88C0D0",
		red = "#BF616A",
		orange = "#D08770",
		yellow = "#EBCB8B",
		magenta = "#B48EAD",
		line = "#3B4252", -- same as gray
	},
	borders = { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
	fold_markers = { "", "" },
	icons = {
		Error = "E",
		Warn = "W",
		Info = "I",
		Hint = "H",
	},
	debug_icons = {
		bug = "",
	},
	kind_icons = {
		Text = "",
		Method = "",
		Function = "",
		Constructor = "",
		Field = "",
		Variable = "",
		Class = "",
		Interface = "",
		Module = "",
		Property = "",
		Unit = "",
		Value = "",
		Enum = "",
		Keyword = "",
		Snippet = "",
		Color = "",
		File = "",
		Reference = "",
		Folder = "",
		EnumMember = "",
		Constant = "",
		Struct = "",
		Event = "",
		Operator = "",
		TypeParameter = "",
	},
}

local fn = vim.fn
local api = vim.api
local cmd = vim.cmd
local keymap = vim.keymap
local lsp = vim.lsp
local vimg = vim.g

local nvim_set_hl = api.nvim_set_hl
---@param highlights table
_G.set_hls = function(highlights)
	for group, opts in pairs(highlights) do
		nvim_set_hl(0, group, opts)
	end
end

---@param cmds table
_G.set_cmds = function(cmds)
	for key, value in pairs(cmds) do
		if type(value) == "string" then
			api.nvim_create_user_command(key, function()
				cmd(value)
			end, {})
		end

		if type(value) == "function" then
			api.nvim_create_user_command(key, value, {})
		end
	end
end

_G.load_plugin_config = function(plugin)
	require("liu.plugins." .. plugin)
end
-- }}}

-- Plugins {{{1
require("lazy").setup(
	{
		-- Colorschemes {{{2
		{
			dir = "$XDG_CONFIG_HOME/nvimplugins/nord",
			priority = 1000, -- make sure to load this before all the other start plugins
			config = function(_, opts)
				require("nord").setup()
			end,
		},
		-- }}}

		-- Libs {{{2
		{
			"nvim-lua/plenary.nvim",
			lazy = true,
			-- event = "VeryLazy",
		},
		-- }}}

		-- UIs {{{2
		{
			"nvim-tree/nvim-web-devicons",
			lazy = true,
			-- event = "VeryLazy",
		},
		{
			"rebelot/heirline.nvim",
			lazy = true,
			-- event = "VeryLazy",
		},
		{
			"stevearc/dressing.nvim",
			event = "VeryLazy",
			opts = {
				input = {
					enabled = true,
					border = config.borders,
				},
				select = {
					enabled = true,
					backend = { "telescope", "builtin" },
					builtin = {
						border = config.borders,
					},
				},
			},
			config = function(_, opts)
				require("dressing").setup(opts)
			end,
		},
		{
			"szw/vim-maximizer",
			cmd = "MaximizerToggle",
		},
		{
			"norcalli/nvim-colorizer.lua",
			opts = {},
			cmd = "ColorizerToggle",
		},
		{
			"utilyre/sentiment.nvim",
			event = "VeryLazy", -- keep for lazy loading
			opts = {},
			init = function()
				-- `matchparen.vim` needs to be disabled manually in case of lazy loading
				vimg.loaded_matchparen = 1
			end,
		},
		{
			"hiphish/rainbow-delimiters.nvim",
			event = "VeryLazy",
			opts = {},
			config = function()
				local rainbow_delimiters = require("rainbow-delimiters")

				vimg.rainbow_delimiters = {
					strategy = {
						[""] = rainbow_delimiters.strategy["global"],
						vim = rainbow_delimiters.strategy["local"],
					},
					query = {
						[""] = "rainbow-delimiters",
						lua = "rainbow-blocks",
					},
					highlight = {
						"RainbowDelimiterRed",
						"RainbowDelimiterYellow",
						"RainbowDelimiterBlue",
						"RainbowDelimiterOrange",
						"RainbowDelimiterGreen",
						"RainbowDelimiterViolet",
						"RainbowDelimiterCyan",
					},
				}

				set_hls({
					RainbowDelimiterRed = { fg = config.colors.red },
					RainbowDelimiterBlue = { fg = config.colors.blue },
					RainbowDelimiterCyan = { fg = config.colors.cyan },
					RainbowDelimiterGreen = { fg = config.colors.green },
					RainbowDelimiterOrange = { fg = config.colors.orange },
					RainbowDelimiterViolet = { fg = config.colors.magenta },
					RainbowDelimiterYellow = { fg = config.colors.yellow },
				})
			end,
		},
		--}}}

		-- LSP {{{2
		{
			"neovim/nvim-lspconfig",
			event = "VeryLazy",
			dependencies = { "folke/neodev.nvim" },
			config = function(_, opts)
				load_plugin_config("lsp")
			end,
		},
		{
			"j-hui/fidget.nvim",
			enabled = false,
			tag = "legacy",
			event = "LspAttach",
			opts = {
				sources = {
					["null-ls"] = {
						ignore = true,
					},
				},
			},
			config = function(_, opts)
				require("fidget").setup(opts)

				set_hls({
					FidgetTask = {
						link = "Comment",
					},
					-- FidgetTitle = { link = "PreProc" },
				})
			end,
		},
		{
			"kosayoda/nvim-lightbulb",
			event = "LspAttach",
			opts = {
				autocmd = {
					enabled = true,
				},
				priority = 100,
				sign = {
					enabled = true,
					text = "💡",
					hl = "LightBulbSign",
				},
			},
			config = function(_, opts)
				require("nvim-lightbulb").setup(opts)
			end,
		},
		{
			"jose-elias-alvarez/null-ls.nvim",
			event = "VeryLazy",
			config = function()
				local nls = require("null-ls")
				local setup = nls["setup"]

				local builtins = nls["builtins"]
				-- local formatting = builtins["formatting"]
				local diagnostics = builtins["diagnostics"]
				-- local hover = builtins["hover"]
				-- local completion = builtins["completion"]
				local actions = builtins["code_actions"]

				local function filter_actions(title)
					return (nil == title:lower():match("blame"))
				end

				local sources = {
					actions.gitsigns.with({
						disabled_filetypes = { "harpoon" },
						config = { filter_actions = filter_actions },
					}),
					diagnostics.golangci_lint,
					-- formatting.stylua,
					-- formatting.shfmt.with({
					-- 	filetypes = { "zsh", "sh" },
					-- }),
				}

				return setup({ sources = sources, border = config.borders })
			end,
		},
		{
			"Wansmer/symbol-usage.nvim",
			enabled = true,
			event = "LspAttach",
			opts = {
				hl = { link = "LspInlayHint" },
				vt_position = "end_of_line",
				references = { enabled = true, include_declaration = false },
				definition = { enabled = false },
				implementation = { enabled = true },
			},
			config = function(_, opts)
				local SymbolKind = vim.lsp.protocol.SymbolKind

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
		{
			"smjonas/inc-rename.nvim",
			event = "LspAttach",
			opts = {
				input_buffer_type = "dressing",
			},
			config = function(_, opts)
				require("inc_rename").setup(opts)
			end,
		},
		-- }}}

		-- DAP {{{2
		{
			"mfussenegger/nvim-dap",
			-- event = "VeryLazy",
			keys = { "<C-s>" }, -- invoke debuging key layer
			cmd = { "DapContinue", "DapToggleBreakpoint" },
			dependencies = {
				"rcarriga/nvim-dap-ui",
				"jbyuki/one-small-step-for-vimkind",
			},
			config = function(self, opts)
				load_plugin_config("dap")

				local dap = require("dap")
				local dapui = require("dapui")

				local ok, libmodal = pcall(require, "libmodal")
				if ok then
					local DESC = "Debuging mode"
					local layer = libmodal.layer.new({})
					local function map(lhs, rhs)
						layer:map("n", lhs, rhs, {})
					end

					-- map("C", dap.continue)
					-- map("X", dap.terminate)
					-- map("R", dap.run_last)
					map("<C-n>", dap.step_over)
					map("<C-p>", dap.step_back)
					map("di", dap.step_into)
					map("do", dap.step_out)
					map("b", dap.toggle_breakpoint)
					map("B", dap.clear_breakpoints)

					map("dv", function()
						dapui.toggle({ layout = 3, reset = true })
					end)
					map("db", function()
						dapui.toggle({ layout = 4, reset = true })
					end)
					map("ds", function()
						dapui.toggle({ layout = 5, reset = true })
					end)
					map("dw", function()
						dapui.toggle({ layout = 6, reset = true })
					end)
					map("dc", function()
						dapui.toggle({ layout = 7, reset = true })
					end)
					map("dr", function()
						dapui.toggle({ layout = 8, reset = true })
					end)

					layer:map("n", "q", function()
						layer:exit()
						vim.g.libmodalActiveLayerName = nil
					end, {})
					local function mode()
						vim.g.libmodalActiveLayerName = "Debuging"
						layer:enter()
					end
					keymap.set("n", self.keys[1], "", { callback = mode, desc = DESC })
				end
			end,
		},
		-- }}}

		-- Treesitter {{{2
		{
			"nvim-treesitter/nvim-treesitter",
			event = "VeryLazy",
			build = ":TSUpdate",
			config = function(_, opts)
				load_plugin_config("treesitter")
			end,
		},
		{
			"nvim-treesitter/nvim-treesitter-context",
			event = "VeryLazy",
			opts = {
				enable = true,
				max_lines = 0,
				min_window_height = 0,
				line_numbers = true,
				multiline_threshold = 20,
				trim_scope = "outer",
				mode = "cursor",
				separator = nil,
				zindex = 20,
			},
			config = function(_, opts)
				require("treesitter-context").setup(opts)

				keymap.set("n", "<leader>cj", function()
					require("treesitter-context").go_to_context()
				end, { silent = true })

				set_hls({
					TreesitterContext = { link = "StatusLine" },
					TreesitterContextLineNumber = { link = "Tag" },
					-- TreesitterContextBottom = { underline = true },
				})
			end,
		},
		{
			"nvim-treesitter/nvim-treesitter-textobjects",
			event = "VeryLazy",
			config = function(_, opts)
				require("nvim-treesitter.configs").setup({
					textobjects = {
						select = {
							enable = true,
							-- Automatically jump forward to textobj, similar to targets.vim
							lookahead = true,
							keymaps = {
								["aa"] = "@parameter.outer",
								["ia"] = "@parameter.inner",
								["af"] = "@function.outer",
								["if"] = "@function.inner",
								["ac"] = "@class.outer",
								["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
							},
							selection_modes = {
								["@parameter.outer"] = "v", -- charwise
								["@function.outer"] = "V", -- linewise
								["@class.outer"] = "<c-v>", -- blockwise
							},
							include_surrounding_whitespace = true,
						},
						move = {
							enable = true,
							set_jumps = true, -- whether to set jumps in the jumplist
							goto_next_start = {
								["]]"] = "@function.outer",
								--
								-- You can use regex matching (i.e. lua pattern) and/or pass a list in a "query" key to group multiple queires.
								-- ["]o"] = "@loop.*",
								-- ["]o"] = { query = { "@loop.inner", "@loop.outer" } }
							},
							goto_next_end = {},
							goto_previous_start = {
								["[["] = "@function.outer",
							},
							goto_previous_end = {},
							-- Below will go to either the start or the end, whichever is closer.
							-- Use if you want more granular movements
							-- Make it even more gradual by adding multiple queries and regex.
							goto_next = {},
							goto_previous = {},
						},
						swap = {
							enable = false,
						},
						lsp_interop = {
							enable = false,
						},
					},
				})
			end,
		},
		{
			"IndianBoy42/tree-sitter-just",
			ft = "just",
			opts = {},
		},

		-- }}}

		-- Fuzzy Finder {{{2
		{
			"nvim-telescope/telescope.nvim",
			event = "VeryLazy",
			config = function()
				local borders = config.borders
				local actions = require("telescope.actions")
				require("telescope").setup({
					defaults = {
						borderchars = {
							borders[2],
							borders[4],
							borders[6],
							borders[8],
							borders[1],
							borders[3],
							borders[5],
							borders[7],
						},
						mappings = {
							i = {
								["<ESC>"] = actions.close,
								["<C-n>"] = actions.move_selection_next,
								["<C-p>"] = actions.move_selection_previous,
							},
							n = {
								["<ESC>"] = actions.close,
							},
						},
						layout_config = {
							horizontal = { prompt_position = "top", preview_width = 0.6, results_width = 0.8 },
							vertical = { mirror = false },
							width = 0.8,
							height = 0.8,
							preview_cutoff = 120,
						},
						sorting_strategy = "ascending",
						winblend = 5,
						path_display = { "truncate" },
						file_ignore_patterns = { "target/", ".git/" },
					},
					pickers = {
						buffers = { mappings = { [{ "i", "n" }] = { ["<c-d>"] = actions.delete_buffer } } },
						live_grep = { mappings = { [{ "i" }] = { ["<c-d>"] = actions.to_fuzzy_refine } } },
						find_files = {
							hidden = true,
							no_ignore = true,
						},
					},
				})

				load_plugin_config("telescope")

				set_hls({ TelescopeBorder = { link = "FloatBorder" } })

				api.nvim_create_autocmd("User", { pattern = "TelescopePreviewerLoaded", command = "setlocal number" })
			end,
		},
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			event = "VeryLazy",
			build = "make",
			cond = function()
				return fn.executable("make") == 1
			end,
			config = function()
				require("telescope").load_extension("fzf")
			end,
		},
		{
			"edolphin-ydf/goimpl.nvim",
			ft = "go",
			config = function()
				require("telescope").load_extension("goimpl")

				api.nvim_create_autocmd("LspAttach", {
					group = api.nvim_create_augroup("User-lspattach-gopls-setup-goimpl", { clear = true }),
					callback = function(args)
						local bufnr = args.buf
						local client_id = args.data.client_id
						local client = lsp.get_client_by_id(client_id)
						if client.name == "gopls" then
							keymap.set("n", "<leader>gi", function()
								require("telescope").extensions.goimpl.goimpl({})
							end, {
								buffer = bufnr,
								desc = "Telescope Goimpl",
								noremap = true,
								silent = true,
							})
							return
						end
					end,
				})
			end,
		},
		{
			"ThePrimeagen/harpoon",
			-- event = "VeryLazy",
			keys = {
				{
					"<C-y>",
					function()
						local mark = require("harpoon.mark")
						mark.add_file()
					end,
				},
				{
					"<C-e>",
					function()
						local ui = require("harpoon.ui")
						ui.toggle_quick_menu()
					end,
				},
				{
					"<C-h>",
					function()
						local ui = require("harpoon.ui")
						ui.nav_prev()
					end,
				},
				{
					"<C-l>",
					function()
						local ui = require("harpoon.ui")
						ui.nav_next()
					end,
				},
			},
			config = function()
				require("harpoon").setup()

				set_hls({ HarpoonBorder = { link = "FloatBorder" } })
			end,
		},
		-- }}}

		-- Text Edit {{{2
		{
			"Wansmer/treesj",
			-- event = "VeryLazy",
			keys = {
				{
					"gj",
					":TSJJoin<CR>",
					silent = true,
					desc = "joining blocks of code like arrays, hashes, statements, objects, dictionaries, etc.",
				},
				{
					"gs",
					":TSJSplit<CR>",
					silent = true,
					desc = "splitting blocks of code like arrays, hashes, statements, objects, dictionaries, etc.",
				},
			},
			cmd = { "TSJSplit", "TSJJoin" },
			opts = { use_default_keymaps = false, max_join_length = 300 },
			config = function(_, opts)
				require("treesj").setup(opts)
			end,
		},
		{
			"numToStr/Comment.nvim",
			-- event = "VeryLazy",
			lazy = true,
			keys = { { "gc", mode = { "n", "x" } }, { "gb", mode = { "n", "x" } } },
			config = function()
				require("Comment").setup({
					ignore = "^$",
				})

				local comment_ft = require("Comment.ft")
				comment_ft.set("lua", { "--%s", "--[[%s]]" })
				comment_ft.set("gowork", { "// %s" })
				comment_ft.set("http", { "# %s" })
				comment_ft.set("just", { "# %s" })
				comment_ft.set("hurl", { "# %s" })
			end,
		},
		{
			"kylechui/nvim-surround",
			event = "VeryLazy",
			config = function()
				require("nvim-surround").setup({
					keymaps = {
						insert = false,
						insert_line = false,
						normal = "ys",
						normal_cur = "yss",
						normal_line = "yS",
						normal_cur_line = false,
						visual = "gs",
						visual_line = false,
						delete = "ds",
						change = "cs",
						change_line = false,
					},
				})
			end,
		},
		{
			"monaqa/dial.nvim",
			keys = {
				{ "<C-a>", "<Plug>(dial-increment)", mode = "n" },
				{ "<C-x>", "<Plug>(dial-decrement)", mode = "n" },
				{ "<C-a>", "<Plug>(dial-increment)", mode = "x" },
				{ "<C-x>", "<Plug>(dial-decrement)", mode = "x" },
				{ "g<C-a>", "g<Plug>(dial-increment)", mode = "x" },
				{ "g<C-x>", "g<Plug>(dial-decrement)", mode = "x" },
			},
			config = function()
				local augend = require("dial.augend")
				local config = require("dial.config")

				local operators = augend.constant.new({
					elements = { "&&", "||" },
					word = false,
					cyclic = true,
				})

				config.augends:register_group({
					default = {
						augend.integer.alias.hex,
						augend.integer.alias.decimal,
						augend.constant.alias.bool,
						augend.date.alias["%Y/%m/%d"],
					},
				})

				config.augends:on_filetype({
					go = {
						augend.integer.alias.decimal,
						augend.integer.alias.hex,
						augend.constant.alias.bool,
						operators,
					},
					toml = {
						augend.integer.alias.decimal,
						augend.semver.alias.semver,
					},
				})
			end,
		},
		{
			"gbprod/substitute.nvim",
			event = "VeryLazy",
			config = function()
				require("substitute").setup({
					highlight_substituted_text = { timer = vim.o.updatetime },
				})
				-- operator
				keymap.set("n", "s", require("substitute").operator, { noremap = true })
				keymap.set("n", "ss", require("substitute").line, { noremap = true })
				keymap.set("n", "S", require("substitute").eol, { noremap = true })
				keymap.set("x", "s", require("substitute").visual, { noremap = true })
				-- exchange
				keymap.set("n", "cx", require("substitute.exchange").operator, { noremap = true })
				keymap.set("n", "cxx", require("substitute.exchange").line, { noremap = true })
				keymap.set("x", "X", require("substitute.exchange").visual, { noremap = true })
				keymap.set("n", "cxc", require("substitute.exchange").cancel, { noremap = true })
			end,
		},
		{
			"tpope/vim-abolish",
			event = "VeryLazy",
		},

		{
			"stevearc/conform.nvim",
			init = function(self)
				vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
			end,
			-- enabled = false,
			-- event = "VeryLazy",
			lazy = true,
			keys = {
				{
					"<leader>F",
					function()
						require("conform").format({ lsp_fallback = true })
					end,
				},
			},
			opts = {
				formatters_by_ft = {
					go = { "gofumpt" },
					lua = { "stylua" },
					rust = { "rustfmt" },
					sh = { "shfmt" },
				},
				-- format_on_save = {
				-- 	lsp_fallback = true,
				-- 	timeout_ms = 500,
				-- },
			},
			config = function(_, opts)
				require("conform").setup(opts)
			end,
		},
		{
			"danymat/neogen",
			cmd = { "Neogen" },
			config = function(self, opts)
				local neogen = require("neogen")
				neogen.setup({
					snippet_engine = "luasnip",
					languages = {
						lua = { template = { annotation_convention = "emmylua" } },
					},
				})
			end,
		},
		{
			"junegunn/vim-easy-align",
			-- enabled = false,
			-- event = "VeryLazy",
			keys = {
				{ "ga", "<Plug>(EasyAlign)", mode = "x" },
			},
			cmd = { "EasyAlign" },
		},
		{
			"tommcdo/vim-lion",
			-- event = "VeryLazy",
			keys = {
				{ "gl", mode = { "n", "x" } },
				{ "gL", mode = { "n", "x" } },
			},
			init = function() end,
		},

		-- }}}

		-- Motion {{{2
		{
			"folke/flash.nvim",
			-- enabled = false,
			-- event = "VeryLazy",
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
			},
			config = function(_, opts)
				require("flash").setup(opts)

				set_hls({
					FlashBackdrop = { fg = config.colors.gray },
				})
			end,
		},
		{
			"wellle/targets.vim",
			event = "VeryLazy",
			config = function()
				-- https://github.com/wellle/targets.vimgtargets_seekranges
				-- Only consider targets around cursor
				vimg.targets_seekRanges = "cc cr cb cB lc ac Ac lr lb ar ab lB Ar aB Ab AB"
			end,
		},
		{
			"chaoren/vim-wordmotion",
			keys = { "<leader>ww" },
			-- event = "VeryLazy",
			init = function()
				vimg.wordmotion_nomap = true
				vimg.wordmotion_prefix = ","
			end,
			config = function(self, opts)
				local ok, libmodal = pcall(require, "libmodal")
				if ok then
					local DESC = "Enter word motion mode"
					local layer = libmodal.layer.new({})
					local function map(modes, lhs, rhs)
						for _, mod in ipairs(modes) do
							layer:map(mod, lhs, rhs, {})
						end
					end
					map({ "n", "x", "o" }, "w", "<Plug>WordMotion_w")
					map({ "x", "o" }, "iw", "<Plug>WordMotion_w")
					map({ "n", "x", "o" }, "b", "<Plug>WordMotion_b")

					layer:map("n", "q", function()
						layer:exit()
						vim.g.libmodalActiveLayerName = nil
					end, {})
					local function mode()
						vim.g.libmodalActiveLayerName = "SubWord"
						layer:enter()
					end
					keymap.set("n", self.keys[1], "", { callback = mode, desc = DESC })
				end
			end,
		},
		{
			"sustech-data/wildfire.nvim",
			-- event = "VeryLazy",
			keys = { "<CR>", "<CR>", "<BS>" },
			config = function(self, _)
				require("wildfire").setup({
					keymaps = {
						init_selection = self.keys[1],
						node_incremental = self.keys[2],
						node_decremental = self.keys[3],
					},
				})
			end,
		},
		-- }}}

		-- Completion {{{2
		{
			"hrsh7th/nvim-cmp",
			event = { "InsertEnter", "CmdlineEnter" },
			dependencies = {
				"hrsh7th/cmp-path",
				"hrsh7th/cmp-buffer",
				"hrsh7th/cmp-cmdline",
				"hrsh7th/cmp-nvim-lsp",
				"hrsh7th/cmp-nvim-lsp-signature-help",
				"hrsh7th/cmp-omni",
				"L3MON4D3/LuaSnip",
				"rafamadriz/friendly-snippets",
				"saadparwaiz1/cmp_luasnip",
			},
			config = function()
				load_plugin_config("cmp")
			end,
		},
		{
			"petertriho/cmp-git",
			cond = function()
				return fn.executable("git") == 1
			end,
			ft = { "gitcommit", "octo" },
			opts = {},
			config = function(self, opts)
				require("cmp_git").setup(opts)

				local cmp = require("cmp")

				cmp.setup.filetype(self.ft, {
					sources = cmp.config.sources({
						{ name = "git" },
					}, {
						{ name = "buffer" },
					}, {
						{ name = "luasnip" },
					}),
				})
			end,
		},
		{
			"windwp/nvim-autopairs",
			event = "InsertEnter",
			opts = {
				check_ts = true,
				fast_wrap = {
					map = "<M-l>",
					-- end_key = "$",
					-- before_key = "h",
					-- after_key = "l",
					manual_position = false,
					use_virt_lines = false,
				},
			},
			config = function(_, opts)
				require("nvim-autopairs").setup(opts)

				local cmp_autopairs = require("nvim-autopairs.completion.cmp")
				local cmp = require("cmp")
				cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
			end,
		},
		-- }}}

		-- Git {{{2
		{
			"tpope/vim-fugitive",
			event = "VeryLazy",
			config = function()
				-- Toggle summary window {{{3
				local fugitivebuf = -1
				keymap.set("n", "<leader>gg", function()
					if fugitivebuf > 0 then
						api.nvim_buf_delete(fugitivebuf, { force = true })
						fugitivebuf = -1
					else
						cmd.G()
					end
				end, { silent = true })
				api.nvim_create_autocmd("User", {
					pattern = { "FugitiveIndex" },
					callback = function(data)
						fugitivebuf = data.buf
						api.nvim_create_autocmd("BufDelete", {
							callback = function()
								fugitivebuf = -1
							end,
							buffer = data.buf,
						})
					end,
				})
				-- }}}

				set_cmds({
					GUndoLastCommit = [[:G reset --soft HEAD~]],
					GDiscardChanges = [[:G reset --hard]],
				})

				set_hls({
					gitDiff = { link = "Normal" },
					diffFile = { fg = config.colors.cyan, italic = true },
					diffNewFile = { fg = config.colors.green, italic = true },
					diffOldFile = { fg = config.colors.yellow, italic = true },
					diffAdded = { link = "DiffAdd" },
					diffRemoved = { link = "DiffDelete" },
					diffLine = { link = "Visual" },
					diffIndexLine = { link = "VisualNC" },
				})
			end,
		},
		{
			"junegunn/gv.vim",
			cmd = { "GV" },
		},
		{
			"lewis6991/gitsigns.nvim",
			event = "VeryLazy",
			config = function()
				local gs = require("gitsigns")

				gs.setup({
					signs = {
						add = { text = "+" },
						change = { text = "~" },
						delete = { text = "_" },
						topdelete = { text = "‾" },
						changedelete = { text = "≃" },
						untracked = { text = "┆" },
					},
					signcolumn = false,
					preview_config = {
						border = config.borders,
						style = "minimal",
						relative = "cursor",
						row = 0,
						col = 1,
					},
					on_attach = function(bufnr)
						local function map(mode, l, r, opts)
							opts = opts or {}
							opts.buffer = bufnr
							keymap.set(mode, l, r, opts)
						end

						-- Text object
						map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")

						-- Navigation
						map("n", "]c", function()
							if vim.wo.diff then
								return "]c"
							end
							vim.schedule(gs.next_hunk)
							return "<Ignore>"
						end, { expr = true })
						map("n", "[c", function()
							if vim.wo.diff then
								return "[c"
							end
							vim.schedule(gs.prev_hunk)
							return "<Ignore>"
						end, { expr = true })

						-- Actions
						map("n", "<leader>hS", gs.stage_buffer, { desc = "Stage buffer" })
						map("n", "<leader>hs", gs.stage_hunk, { desc = "Stage hunk" })
						map("v", "<leader>hs", function()
							gs.stage_hunk({ fn.line("."), fn.line("v") })
						end, { desc = "Stage hunk" })

						map("n", "<leader>hR", gs.reset_buffer, { desc = "Reset buffer" })
						map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
						map("v", "<leader>hr", function()
							gs.reset_hunk({ fn.line("."), fn.line("v") })
						end, { desc = "Reset hunk" })

						map("n", "<leader>hd", gs.diffthis)
						map("n", "<leader>hD", function()
							gs.diffthis("~")
						end)

						map("n", "<leader>hp", gs.preview_hunk)
					end,
				})

				set_hls({
					GitSignsAdd = { fg = config.colors.green },
					GitSignsAddNr = { fg = config.colors.green },
					GitSignsAddLn = { fg = config.colors.green, bg = config.colors.line },
					GitSignsChange = { fg = config.colors.yellow },
					GitSignsChangeNr = { fg = config.colors.yellow },
					GitSignsChangeLn = { fg = config.colors.yellow, bg = config.colors.line },
					GitSignsDelete = { fg = config.colors.red },
					GitSignsDeleteNr = { fg = config.colors.red },
					GitSignsDeleteLn = { fg = config.colors.red, bg = config.colors.line },
				})
			end,
		},
		{
			"rhysd/git-messenger.vim",
			cmd = { "GitMessenger" },
			config = function()
				vimg.git_messenger_no_default_mappings = true
				vimg.git_messenger_floating_win_opts = { border = config.borders }
			end,
		},
		{
			"akinsho/git-conflict.nvim",
			enabled = true,
			event = "VeryLazy",
			config = function()
				require("git-conflict").setup({
					default_mappings = false,
					default_commands = true,
				})

				api.nvim_create_autocmd("User", {
					pattern = "GitConflictDetected",
					callback = function(args)
						vim.notify("[Git] Conflict detected!", vim.log.levels.WARN)

						local bufnr = args.buf
						local map = function(lhs, rhs)
							keymap.set("n", lhs, rhs)
						end

						map("Co", "<Plug>(git-conflict-ours)")
						map("Ct", "<Plug>(git-conflict-theirs)")
						map("Cb", "<Plug>(git-conflict-both)")
						map("C0", "<Plug>(git-conflict-none)")
						map("[x", "<Plug>(git-conflict-prev-conflict)")
						map("]x", "<Plug>(git-conflict-next-conflict)")
					end,
				})

				api.nvim_create_autocmd("User", {
					pattern = "GitConflictResolved",
					callback = function(args)
						vim.notify("[Git] Conflict resolved!", vim.log.levels.INFO)
					end,
				})
			end,
		},
		-- }}}

		-- Repeat {{{2
		{ "tpope/vim-repeat", event = "VeryLazy" },
		{
			"ghostbuster91/nvim-next",
			-- enabled = false,
			event = "VeryLazy",
			config = function(_, opts)
				local nvim_next_builtins = require("nvim-next.builtins")
				require("nvim-next").setup({
					default_mappings = {
						repeat_style = "original",
					},
					items = {
						nvim_next_builtins.f,
						nvim_next_builtins.t,
					},
				})

				local next_move = require("nvim-next.move")

				local diagnostic = vim.diagnostic
				local prev_diag_item, next_diag_item =
					next_move.make_repeatable_pair(diagnostic.goto_prev, diagnostic.goto_next)
				keymap.set("n", "[d", prev_diag_item)
				keymap.set("n", "]d", next_diag_item)

				local make_repeatable_cmd_pair = function(prev, next)
					local checkerr = function(status)
						if not status then
							vim.notify("Can Not Move", vim.log.levels.INFO)
						end
					end
					return next_move.make_repeatable_pair(function(_)
						local status, _ = pcall(cmd, prev)
						checkerr(status)
					end, function(_)
						local status, _ = pcall(cmd, next)
						checkerr(status)
					end)
				end

				local prev_qf_item, next_qf_item = make_repeatable_cmd_pair("cprev", "cnext")
				keymap.set("n", "]q", next_qf_item, { desc = "repeat: next quickfix" })
				keymap.set("n", "[q", prev_qf_item, { desc = "repeat: prev quickfix" })

				local prev_ll_item, next_ll_item = make_repeatable_cmd_pair("lprev", "lnext")
				keymap.set("n", "]l", next_ll_item, { desc = "repeat: next local quickfix" })
				keymap.set("n", "[l", prev_ll_item, { desc = "repeat: prev local quickfix" })
			end,
		},
		{
			"Iron-E/nvim-libmodal",
			lazy = true,
			keys = {
				"<leader>zj",
			},
			-- event = "VeryLazy",
			config = function(self, opts)
				local libmodal = require("libmodal")
				do
					local DESC = "Enter flod mode"
					local function mode()
						libmodal.layer.enter({
							n = {
								j = {
									rhs = "zj",
									noremap = true,
								},
								k = {
									rhs = "zk",
									noremap = true,
								},
							},
						}, "q")
					end
					keymap.set("n", self.keys[1], "", { callback = mode, desc = DESC })
				end
			end,
		},
		-- {
		-- 	"Iron-E/nvim-tabmode",
		-- 	cmd = "TabmodeEnter", -- don't load until using this command
		-- 	config = true, -- automatically call `bufmode.setup()`; not needed if you specify `opts`
		-- 	keys = { { "<Leader><Tab>", desc = "Enter buffer mode", mode = "n" } }, -- don't load until pressing these keys
		-- 	-- opts = {}, (put `setup` options here, e.g. `opts = {enter_mapping = false}`
		-- },
		-- }}}

		-- Misc {{{2
		{
			"lewis6991/hover.nvim",
			event = "VeryLazy",
			config = function()
				require("hover").setup({
					init = function()
						require("hover.providers.lsp")
						require("hover.providers.gh")
						require("hover.providers.gh_user")
						require("hover.providers.man")
					end,
					preview_opts = {
						border = config.borders,
					},
					preview_window = false,
					title = true,
				})

				-- Setup keymaps
				keymap.set("n", "K", require("hover").hover, { desc = "hover.nvim" })
				keymap.set("n", "gK", require("hover").hover_select, { desc = "hover.nvim (select)" })
			end,
		},
		{
			"mbbill/undotree",
			-- event = "VeryLazy",
			cmd = { "UndotreeToggle" },
			keys = {
				{
					"<leader>u",
					cmd.UndotreeToggle,
					desc = "Undotree: Toggle",
					noremap = true,
					silent = true,
				},
			},
			config = function()
				vimg.undotree_WindowLayout = 2
				vimg.undotree_DiffAutoOpen = 1
				vimg.undotree_ShortIndicators = 1
				vimg.undotree_SetFocusWhenToggle = 1
			end,
		},
		{
			"Bekaboo/dropbar.nvim",
			enabled = true,
			event = "VeryLazy",
			keys = {
				{
					"<leader>dp",
					function()
						require("dropbar.api").pick()
					end,
				},
			},
			opts = {
				general = {
					---@type boolean|fun(buf: integer, win: integer): boolean
					enable = function(buf, win)
						if vim.tbl_contains({ "", "git", "fugitive", "GV", "toggleterm" }, vim.bo[buf].filetype) then
							return false
						end

						for _, pattern in ipairs({ "fugitive:///" }) do
							local fname = api.nvim_buf_get_name(buf)
							if string.match(fname, pattern) then
								return false
							end
						end

						if vim.bo[buf].buftype ~= "" then
							return false
						end

						if vim.wo[win].diff then
							return false
						end

						return not api.nvim_win_get_config(win).zindex
					end,
				},
				icons = {
					kinds = {
						use_devicons = true,
					},
				},
				menu = {
					keymaps = {
						["<CR>"] = function()
							local menu = require("dropbar.api").get_current_dropbar_menu()
							if not menu then
								return
							end
							local cursor = api.nvim_win_get_cursor(menu.win)
							local component = menu.entries[cursor[1]]:first_clickable(cursor[2])
							if component then
								menu:click_on(component, nil, 1, "l")
							end
						end,
						["q"] = function()
							cmd.quit()
						end,
					},
					win_configs = {
						border = config.borders,
					},
				},
			},
		},
		{
			"rgroli/other.nvim",
			cmd = { "Other", "OtherVSplit" },
			config = function()
				require("other-nvim").setup({
					mappings = {
						"golang",
					},
					style = {
						border = config.borders,
					},
				})
			end,
		},
		{
			"stevearc/oil.nvim",
			cmd = { "Oil", "OilSSH" },
			keys = { "-" },
			config = function(self, opts)
				require("oil").setup({
					keymaps = {
						["q"] = {
							callback = function()
								for _, bufnr in ipairs(api.nvim_list_bufs()) do
									if api.nvim_buf_get_name(bufnr):match("oil://.*") then
										api.nvim_buf_delete(bufnr, { force = true })
									end
								end
							end,
						},
					},
					float = {
						padding = 1,
						border = config.borders,
					},
				})

				keymap.set("n", "-", function()
					require("oil").open()
				end)

				api.nvim_create_user_command("OilSSH", function(opts)
					local url = opts.fargs[1]
					local r = string.gsub(url, ":/", "//")
					cmd(string.format("Oil oil-ssh://%s", r))
				end, { nargs = 1 })
			end,
		},
		{
			"lambdalisue/suda.vim",
			cmd = { "SudaRead", "SudaWrite" },
		},
		{ "tpope/vim-sleuth", event = "VeryLazy" },
		{
			"tpope/vim-dispatch",
			-- event = "VeryLazy",
			init = function()
				vimg.dispatch_no_maps = 1
			end,
			cmd = { "Make", "Dispatch", "Start" },
		},
		{
			"tpope/vim-dadbod",
			cmd = { "DB" },
			ft = { "sql" },
			config = function()
				cmd([[
				 nmap <expr> Q db#op_exec()
				 xmap <expr> Q db#op_exec()
				]])
			end,
		},
		{
			"akinsho/toggleterm.nvim",
			-- event = "VeryLazy",
			keys = { [[<c-\>]] },
			opts = {
				on_open = function(t)
					vim.o.ch = 0
				end,
				on_close = function(t)
					vim.o.ch = 1
				end,
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
			"pwntester/octo.nvim",
			cond = function()
				return fn.executable("gh") == 1
			end,
			-- event = "VeryLazy",
			cmd = { "Octo" },
			opts = {
				enable_builtin = true,
				timeout = 3000,
			},
			config = function(_, opts)
				require("octo").setup(opts)

				vim.treesitter.language.register("markdown", "octo")
			end,

			-- config = function() end,
		},
		{
			"simeji/winresizer",
			init = function(self)
				-- disable the start key
				-- https://github.com/simeji/winresizer/pull/19#issuecomment-925097954
				-- vimg.winresizer_start_key = "<NOP>"

				vimg.winresizer_start_key = self.keys[1]
			end,
			keys = { "<leader>e" },
			cmd = { "WinResizerStartResize" },
		},
		{
			"ojroques/nvim-osc52",
			cond = function()
				return os.getenv("SSH_CLIENT")
			end,
			config = function(_, opts)
				require("osc52").setup({
					max_length = 0, -- Maximum length of selection (0 for no limit)
					silent = false, -- Disable message on successful copy
					trim = false, -- Trim surrounding whitespaces before copy
				})

				local function copy(lines, _)
					require("osc52").copy(table.concat(lines, "\n"))
				end

				local function paste()
					return {
						vim.fn.split(vim.fn.getreg(""), "\n"),
						vim.fn.getregtype(""),
					}
				end

				vim.g.clipboard = {
					name = "osc52",
					copy = { ["+"] = copy, ["*"] = copy },
					paste = { ["+"] = paste, ["*"] = paste },
				}
			end,
		},
		{
			"luckasRanarison/nvim-devdocs",
			cmd = {
				"DevdocsFetch",
				"DevdocsOpenFloat",
				"DevdocsOpenCurrentFloat",
			},
			-- event = "VeryLazy",
			opts = {
				float_win = { -- passed to nvim_open_win(), see :h api-floatwin
					relative = "editor",
					height = 25,
					width = 100,
					border = config.borders,
				},
				after_open = function(bufnr)
					keymap.set("n", "q", ":close<CR>", { silent = true, buffer = bufnr })
				end,
			},
		},
		-- }}}

		-- Lang {{{2
		{
			"romainl/vim-qf",
			init = function(self)
				vimg.qf_mapping_ack_style = 1
			end,
			ft = "qf",
		},
		{
			"Olical/nfnl",
			ft = "fennel",
		},
		{
			"saecki/crates.nvim",
			event = { "BufRead Cargo.toml" },
			init = function()
				api.nvim_create_autocmd("BufRead", {
					group = api.nvim_create_augroup("UserSetCargoCmpSource", { clear = true }),
					pattern = "Cargo.toml",
					callback = function()
						local cmp = require("cmp")
						cmp.setup.buffer({ sources = { { name = "crates" } } })
					end,
				})
			end,
			config = function()
				require("crates").setup({
					popup = {
						border = config.borders,
					},
					null_ls = {
						enabled = true,
						name = "crates.nvim",
					},
				})

				-- Hover {{{
				local crates = require("crates")
				local fns = {
					popup = { fn = crates.show_popup, priority = 1010 },
					versions = { fn = crates.show_versions_popup, priority = 1009 },
					features = { fn = crates.show_features_popup, priority = 1008 },
					dependencies = { fn = crates.show_dependencies_popup, priority = 1007 },
				}
				for key, val in pairs(fns) do
					require("hover").register({
						name = string.format("Crates: %s", key),
						enabled = function()
							return fn.expand("%:t") == "Cargo.toml"
						end,
						execute = function(done)
							val.fn()
						end,
						priority = val.priority,
					})
				end
				-- }}}
			end,
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
					"matchparen",
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
			notify = true,
		},
		install = {
			missing = true,
			colorscheme = { vimg.colors_name },
		},
		ui = {
			border = config.borders,
			icons = {
				cmd = "⌘",
				config = "🛠",
				event = "📅",
				ft = "📂",
				init = "⚙",
				keys = "🗝",
				plugin = "🔌",
				runtime = "💻",
				source = "📄",
				start = "🚀",
				task = "📌",
				lazy = "💤 ",
			},
		},
	}
	-- }}}
)
-- }}}

-- Sets {{{1
vim.o.mouse = ""
vim.o.clipboard = "unnamedplus"
-- Open the command-line window in command-line Mode.
vim.o.cedit = "<C-Y>"

vim.o.splitright = true
vim.o.splitbelow = false

-- UI {{{2
vim.o.termguicolors = true

vim.wo.number = true
vim.wo.relativenumber = true

vim.wo.signcolumn = "yes"

vim.o.laststatus = 3
vim.o.showmode = false
vim.o.showcmd = false

vim.o.pumheight = 12

vim.o.scrolloff = 3

vim.o.cursorline = true
cmd([[
	set guicursor=n-v:block,i-c-ci-ve:ver25,r-cr:hor20,o:hor50
	  \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
	  \,sm:block-blinkwait175-blinkoff150-blinkon175
]])
-- }}}

-- Search{{{2
vim.o.hlsearch = false
vim.o.incsearch = true

vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.infercase = true

if fn.executable("rg") == 1 then
	vim.o.grepprg = "rg --vimgrep"
end
-- }}}

-- Undo {{{2
vim.o.undofile = true
vim.o.undodir = os.getenv("HOME") .. "/.vim/undodir"
-- }}}

-- Time {{{2
vim.o.timeout = true
vim.o.timeoutlen = 300
vim.o.updatetime = 300
-- }}}

-- wrap {{{2
vim.o.wrap = false
vim.o.whichwrap = "b,s,<,>,h,l"
-- }}}

-- Folding{{{2
-- vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
-- Filling `foldtext` with space
vim.opt.fillchars:append("fold: ")
vim.opt.fillchars:append("foldopen:")
vim.opt.fillchars:append("foldclose:")
-- vim.opt.fillchars:append("foldsep:|")
-- }}}

-- Avoid showing the intro when starting Neovim
vim.opt.shortmess:append("I")
-- }}}

-- Remaps {{{1
local mapopts = { silent = true, noremap = true }
local setmap = function(mode, lhs, rhs, opts)
	opts = opts or mapopts
	keymap.set(mode, lhs, rhs, opts)
end

-- Toggle Opt{{{2
local function toggle_opt(op, option, opts)
	if not opts then
		return setmap("n", ("co" .. op), (":set " .. option .. "!" .. "<bar> set " .. option .. "?<cr>"))
	else
		if opts.val then
			local vv = opts.val
			return setmap("n", "co" .. op, function()
				vim.o[option], vv = vv, vim.o[option]
				cmd(string.format("set %s?", option))
			end)
		end

		if opts.option then
			local vals = { opts.option, option }
			local idx = 0
			return setmap("n", "co" .. op, function()
				local val = vals[idx % 2 + 1]
				cmd(string.format("set %s | set %s?", val, val))
				idx = idx + 1
			end)
		end

		if opts.fns then
			local idx = 0
			return setmap("n", "co" .. op, function()
				cmd(string.format("set %s! | set %s?", option, option))

				local fn = opts.fns[idx % 2 + 1]
				fn()

				idx = idx + 1
			end)
		end
	end
end

toggle_opt("w", "wrap", {
	fns = {
		function()
			-- Remap for dealing with word wrap
			setmap({ "n", "x" }, "k", "gk")
			setmap({ "n", "x" }, "j", "gj")
		end,
		function()
			keymap.del({ "n", "x" }, "k")
			keymap.del({ "n", "x" }, "j")
		end,
	},
})
toggle_opt("h", "hlsearch", { option = "nohlsearch" })
toggle_opt("m", "mouse", { val = "a" })
toggle_opt("t", "laststatus", { val = 0 })
-- }}}

-- Emacs like {{{2
setmap("i", "<C-a>", "<HOME>")
setmap("i", "<C-e>", "<END>")
setmap("i", "<C-f>", "<right>")
setmap("i", "<C-b>", "<left>")

local function rtf(keys, mode)
	local tkeys = api.nvim_replace_termcodes(keys, true, true, true)
	return function()
		return api.nvim_feedkeys(tkeys, mode, false)
	end
end
setmap("c", "<C-a>", rtf("<HOME>", "c"))
setmap("c", "<C-e>", rtf("<END>", "c"))
setmap("c", "<C-b>", rtf("<left>", "c"))
setmap("c", "<C-f>", rtf("<right>", "c"))

-- not
setmap("c", "<C-j>", rtf("<down>", "c"))
setmap("c", "<C-k>", rtf("<up>", "c"))
-- }}}

-- Text {{{2
setmap("n", "Y", "y$")
setmap("x", "Y", "<ESC>y$gv")

setmap("x", "K", ":move '<-2<CR>gv=gv")
setmap("x", "J", ":move '>+1<CR>gv=gv")

setmap("x", "<", "<gv")
setmap("x", ">", ">gv")

-- keep the old word in the clipboard
setmap("x", "p", '"_dP')
-- changing a word, use dot do repeat
setmap("n", "cn", [[*``"_cgn]])
-- changing a selection, use dot do repeat
-- "ry -- copy the selection to `r` register
-- let @/=escape(@r, '/') -- add the current selection from `r` register to the "search register"
-- "_ -- next operation store the text in the _ register
-- cgn -- replace the closest match to the search
setmap("x", "cn", [["ry<cmd>let @/=escape(@r, '/')<cr>"_cgn]])
-- use the substitute function to replace the newline character with \n
-- setmap("x", "cn", [[y<cmd>substitute(escape(@", '/'), '\n', '\\n', 'g')<cr>"_cgn]] )

setmap("n", "<leader>g;", "mqA;<ESC>`q")
setmap("n", "<leader>g,", "mqA,<ESC>`q")
-- }}}

-- Exit {{{2
setmap("i", "jj", "<Esc>")
setmap("i", "kk", "<Esc>")

setmap("n", "<C-q>", ":quit<CR>")
-- }}}

-- Movement {{{2
-- HJKL as amplified versions of hjkl
setmap({ "n", "x", "o" }, "H", "^")
setmap({ "n", "x", "o" }, "L", "$")
-- Keep cursor in the center
setmap("n", "<C-d>", "<C-d>zz")
setmap("n", "<C-u>", "<C-u>zz")
setmap("n", "n", "nzzzv")
setmap("n", "N", "Nzzzv")
-- }}}

-- QF {{{
setmap("n", "<leader>cc", "<cmd>try | cclose | lclose | tabclose | catch | endtry <cr>")

setmap("n", "[q", "<cmd>try | cprev | catch | silent! clast | catch | endtry<cr>zv")
setmap("n", "]q", "<cmd>try | cnext | catch | silent! cfirst | catch | endtry<cr>zv")

setmap("n", "[l", ":lprev<cr>")
setmap("n", "]l", ":lnext<cr>")
-- }}}

-- Delete Mark{{{
vim.keymap.set("n", "dm", function()
	local mark = vim.fn.getcharstr()
	local ditgit = string.byte(mark)
	if (ditgit >= 65 and ditgit <= 90) or (ditgit >= 97 and ditgit <= 122) then
		vim.api.nvim_command(string.format(":delm %s<CR>", mark))
	end
end, { noremap = true })
-- use M jump to mark
setmap("n", "M", "g'")
-- }}}

-- Abbrev{{{
local opts = {
	expr = true,
	desc = "fixing that stupid typo when trying to [save]exit",
	noremap = true,
}
setmap("ca", "W", "((getcmdtype()  is# ':' && getcmdline() is# 'W')?('w'):('W'))", opts)
setmap("ca", "Q", "((getcmdtype()  is# ':' && getcmdline() is# 'Q')?('q'):('Q'))", opts)
-- }}}

setmap("n", "<C-w>O", ":tabonly<CR>")
-- }}}

-- Cmds {{{1
api.nvim_create_user_command("FindAndReplace", function(opts)
	if #opts.fargs ~= 2 then
		vim.print("Two argument required.")
	end
	api.nvim_command(string.format("silent cdo s/%s/%s", opts.fargs[1], opts.fargs[2]))
	api.nvim_command("silent cfdo update")
end, {
	nargs = "*",
	desc = "Find and Replace (after quickfix)",
})
-- }}}

-- Autocmds {{{1
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local general = augroup("UserGeneralSettings", { clear = true })
autocmd("TextYankPost", {
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({
			timeout = vim.o.updatetime,
			priority = vim.highlight.priorities.user + 1,
		})
	end,
	group = general,
	desc = "Highlight when yanking",
})
autocmd("VimResized", {
	group = general,
	command = "wincmd =",
	desc = "Equalize Splits",
})
autocmd("FocusGained", {
	callback = function()
		-- normal buffer
		if vim.o.bt == "" then
			cmd("checktime")
		end
	end,
	group = general,
	desc = "Update file when there are changes",
})
autocmd("BufWritePre", {
	group = general,
	command = "%s/\\s\\+$//e",
	desc = "Trim Trailing",
})
autocmd("BufEnter", {
	callback = function()
		vim.opt.formatoptions:remove({ "c", "r", "o" })
	end,
	group = general,
	desc = "Disable New Line Comment",
})
autocmd({ "BufWinLeave", "BufLeave", "InsertLeave", "FocusLost" }, {
	callback = function()
		cmd("silent! w")
	end,
	group = general,
	desc = "Auto Save when leaving insert mode, buffer or window",
})
autocmd("ModeChanged", {
	callback = function()
		local cmdtype = fn.getcmdtype()
		if cmdtype == "/" or cmdtype == "?" then
			vim.opt.hlsearch = true
		else
			vim.opt.hlsearch = false
		end
	end,
	group = general,
	desc = "Highlighting matched words when searching",
})
-- :h last-position-jump
autocmd("BufReadPost", {
	callback = function()
		if fn.line("'\"") > 1 and fn.line("'\"") <= fn.line("$") then
			cmd('normal! g`"')
		end
	end,
	group = general,
	desc = "Go To The Last Cursor Position",
})
autocmd("BufWinEnter", {
	group = augroup("UserOpenHelpInTab", {}),
	pattern = { "*.txt" },
	callback = function()
		if vim.o.filetype == "help" then
			cmd.wincmd("T")
		end
	end,
	desc = "Open help file in a new table",
})
-- }}}

-- Diagnostic {{{1
-- https://neovim.io/doc/user/diagnostic.html
local diagnostic = vim.diagnostic
diagnostic.config({
	underline = { severity = { min = diagnostic.severity.INFO } },
	signs = { severity = { min = diagnostic.severity.INFO } },
	float = { source = true, border = config.borders, show_header = false },
	severity_sort = true,
	virtual_text = false,
	update_in_insert = false,
})

keymap.set("n", "[d", diagnostic.goto_prev)
keymap.set("n", "]d", diagnostic.goto_next)
-- keymap.set("n", "<leader>dd", diagnostic.open_float)
-- keymap.set("n", "<leader>dq", diagnostic.setloclist)

fn.sign_define("DiagnosticSignError", { text = config.icons.Error, texthl = "DiagnosticSignError" })
fn.sign_define("DiagnosticSignWarn", { text = config.icons.Warn, texthl = "DiagnosticSignWarn" })
fn.sign_define("DiagnosticSignInfo", { text = config.icons.Info, texthl = "DiagnosticSignInfo" })
fn.sign_define("DiagnosticSignHint", { text = config.icons.Hint, texthl = "DiagnosticSignHint" })

local ok, hover = pcall(require, "hover")
if ok then
	hover.register({
		name = "Diagnostic",
		enabled = function()
			local diags = diagnostic.get(0)
			if #diags == 0 then
				return false
			end

			local pos = api.nvim_win_get_cursor(0)
			local lnum = pos[1] - 1
			local col = pos[2]
			local line_length = #api.nvim_buf_get_lines(0, lnum, lnum + 1, true)[1]
			local ds = vim.tbl_filter(function(d)
				return d.lnum == lnum
					and math.min(d.col, line_length - 1) <= col
					and (d.end_col >= col or d.end_lnum > lnum)
			end, diags)

			if vim.tbl_isempty(ds) then
				return false
			end
			return true
		end,
		execute = function(done)
			diagnostic.open_float()
		end,
		priority = 1000,
	})
end
-- }}}

-- Lsp {{{1
-- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
lsp.set_log_level("OFF")

-- local autocmd = api.nvim_create_autocmd
-- local augroup = api.nvim_create_augroup

-- keymaps
autocmd("LspAttach", {
	group = augroup("UserLspAttachKeymaps", { clear = true }),
	callback = function(args)
		local bufnr = args.buf

		vim.bo[bufnr].omnifunc = "v:lua.lsp.omnifunc"
		-- vim.bo[bufnr].tagfunc = "v:lua.lsp.tagfunc"
		-- vim.bo[bufnr].formatexpr = "v:lua.lsp.formatexpr(#{timeout_ms:250})"

		local nmap = function(keys, func, desc)
			if desc then
				desc = "LSP: " .. desc
			end
			keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
		end

		local client = lsp.get_client_by_id(args.data.client_id)
		if client.supports_method("textDocument/rename") then
			nmap("<leader>rn", lsp.buf.rename, "[R]e[n]ame")
		end

		nmap("<leader>ca", lsp.buf.code_action, "[C]ode [A]ction")
		nmap("<leader>cl", lsp.codelens.run, "[C]ode [L]en")

		-- nmap("gd", lsp.buf.definition, "[G]oto [D]efinition")
		-- nmap("<leader>vd", "<cmd>vsplit | lua lsp.buf.definition()<CR>", "[G]oto [D]efinition")
		-- nmap("gD", lsp.buf.type_definition, "[G]oto Type [D]efinition")

		-- nmap('gD', lsp.buf.declaration, '[G]oto [D]eclaration')

		-- nmap("K", lsp.buf.hover, "Hover Documentation")
		-- nmap("<C-k>", lsp.buf.signature_help, "Signature Documentation")
	end,
})

-- workspace
autocmd("LspAttach", {
	group = augroup("UserLspAttachWorkspaceFolderCmds", { clear = true }),
	callback = function(args)
		local bufnr = args.buf
		local client = lsp.get_client_by_id(args.data.client_id)

		api.nvim_create_user_command("LspAddWorkspaceFolder", function(opts)
			lsp.buf.add_workspace_folder()
		end, { nargs = 0 })

		api.nvim_create_user_command("LspDeleteWorkspaceFolder", function(opts)
			local wsfs = lsp.buf.list_workspace_folders()

			vim.ui.select(wsfs, {
				prompt = "Remove Workspace Folder",
				format_item = function(item)
					return "Remove: " .. item
				end,
			}, function(choice)
				lsp.buf.remove_workspace_folder(choice)
			end)
		end, { nargs = 0 })

		api.nvim_create_user_command("LspListWorkspaceFolder", function(opts)
			vim.print(lsp.buf.list_workspace_folders())
		end, { nargs = 0 })
	end,
})

-- codelens
autocmd("LspAttach", {
	group = augroup("UserLspAttachCodelens", { clear = true }),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if client.supports_method("textDocument/codeLens") then
			local bufnr = args.buf
			autocmd({ "CursorHold", "InsertLeave" }, {
				callback = function()
					lsp.codelens.refresh()
				end,
				buffer = 0,
			})
		end
	end,
})

-- inlayhint
autocmd("LspAttach", {
	group = augroup("UserLspAttachInlayHint", { clear = true }),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if client.supports_method("textDocument/inlayHint") then
			local bufnr = args.buf
			if lsp.inlay_hint then
				lsp.inlay_hint(bufnr, true)
				return
			end
		end
	end,
})

-- document highlight
autocmd("LspAttach", {
	group = augroup("UserLspAttachDocumentHighlight", { clear = true }),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		local bufnr = args.buf
		if client.server_capabilities.documentHighlightProvider then
			api.nvim_create_augroup("UserLspDocumentHighlight", {
				clear = false,
			})
			api.nvim_clear_autocmds({
				buffer = bufnr,
				group = "UserLspDocumentHighlight",
			})
			api.nvim_create_autocmd({ "CursorHold" }, {
				group = "UserLspDocumentHighlight",
				buffer = bufnr,
				callback = function()
					lsp.buf.document_highlight()
				end,
			})
			api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				group = "UserLspDocumentHighlight",
				buffer = bufnr,
				callback = function()
					lsp.buf.clear_references()
				end,
			})
		end
	end,
})

-- handlers {{{
local oldhover = lsp.handlers.hover
local oldsignature = lsp.handlers.signature_help
lsp.handlers["textDocument/hover"] = lsp.with(oldhover, { border = config.borders })
lsp.handlers["textDocument/signatureHelp"] = lsp.with(oldsignature, { border = config.borders })
-- lsp.handlers["workspace/diagnostic/refresh"] = function(_, _, ctx)
-- 	local bufnr = api.nvimget_current_buf()
-- 	local ns = lsp.diagnostic.get_namespace(ctx.client_id)
-- 	diagnostic.reset(ns, bufnr)

-- 	vim.notify("Diagnostic: refresh", vim.log.levels.WARN)
-- 	return true
-- end
-- }}}

-- }}}

-- vim: foldmethod=marker