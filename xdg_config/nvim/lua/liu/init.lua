local fn = vim.fn
local api = vim.api
local cmd = vim.cmd
local keymap = vim.keymap
local lsp = vim.lsp
local lsp_protocol = vim.lsp.protocol
local vimg = vim.g
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

-- Global Things {{{1

-- symbol and completion item {{{2
local completion_item_kinds = {
	-- https://code.visualstudio.com/docs/editor/intellisense#_types-of-completions
	-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItemKind
	Text = { icon = " ", hl = "@text" },
	Method = { icon = "󰆧 ", hl = "@method" },
	Function = { icon = "󰊕 ", hl = "@function" },
	Constructor = { icon = " ", hl = "@constructor" },
	Field = { icon = " ", hl = "@field" },
	Variable = { icon = "󰀫 ", hl = "@variable" },
	Class = { icon = " ", hl = "@type" },
	Interface = { icon = " ", hl = "@type" },
	Module = { icon = " ", hl = "@include" },
	Property = { icon = " ", hl = "@property" },
	Unit = { icon = " ", hl = "@text" },
	Value = { icon = "󰎠 ", hl = "@text" },
	Enum = { icon = " ", hl = "@type" },
	Keyword = { icon = " ", hl = "@keyword" },
	Snippet = { icon = " ", hl = "@text" },
	Color = { icon = "󰏘 ", hl = "@text" },
	File = { icon = "󰈙 ", hl = "@text" },
	Reference = { icon = " ", hl = "@text.reference" },
	Folder = { icon = " ", hl = "Directory" },
	EnumMember = { icon = " ", hl = "@constant" },
	Constant = { icon = " ", hl = "@constant" },
	Struct = { icon = " ", hl = "@type" },
	Event = { icon = " ", hl = "@text" },
	Operator = { icon = "󰆕 ", hl = "@operator" },
	TypeParameter = { icon = " ", hl = "@type" },
}

local symbol_kinds = {
	-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#symbolKind
	File = completion_item_kinds.File,
	Module = completion_item_kinds.Module,
	Namespace = { icon = " ", hl = "Macro" },
	Package = { icon = " ", hl = "Macro" },
	Class = completion_item_kinds.Class,
	Method = completion_item_kinds.Method,
	Property = completion_item_kinds.Property,
	Field = completion_item_kinds.Field,
	Constructor = completion_item_kinds.Constructor,
	Enum = completion_item_kinds.Enum,
	Interface = completion_item_kinds.Interface,
	Function = completion_item_kinds.Function,
	Variable = completion_item_kinds.Variable,
	Constant = completion_item_kinds.Constant,
	String = completion_item_kinds.String,
	Number = completion_item_kinds.Number,
	Boolean = completion_item_kinds.Boolean,
	Array = { icon = "󰅪 ", hl = "Identifier" },
	Object = completion_item_kinds.Object,
	Key = completion_item_kinds.Key,
	Null = completion_item_kinds.Null,
	EnumMember = completion_item_kinds.EnumMember,
	Struct = completion_item_kinds.Struct,
	Event = completion_item_kinds.Event,
	Operator = completion_item_kinds.Operator,
	TypeParameter = completion_item_kinds.TypeParameter,
}
-- }}}

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
	icons = {
		symbol_kinds = symbol_kinds,
		completion_item_kinds = completion_item_kinds,
		diagnostics = {
			-- ERROR = "E",
			-- WARN = "W",
			-- INFO = "I",
			-- HINT = "H",

			ERROR = "",
			WARN = "",
			INFO = "",
			HINT = "",

			-- ERROR = "Ⓔ",
			-- WARN = "Ⓦ",
			-- INFO = "Ⓘ",
			-- HINT = "Ⓗ",
		},
		arrows = {
			right = "",
			left = "",
			up = "",
			down = "",
		},
		fold = { "", "" },
		directory = " ",
		bug = "",
		git = "",
		bulb = "💡",
		search = "",
	},
}

local nvim_set_hl = api.nvim_set_hl
---@param highlights table
_G.set_hls = function(highlights)
	for group, opts in pairs(highlights) do
		nvim_set_hl(0, group, opts)
	end
end

---@param cmds table
_G.set_cmds = function(cmds)
	for key, cmd in pairs(cmds) do
		api.nvim_create_user_command(key, cmd, {})
	end
end

local load_plugin_config = function(plugin)
	require("liu.plugins." .. plugin)
end

local user_augroup = function(name)
	return vim.api.nvim_create_augroup("liu_" .. name, { clear = true })
end
-- }}}

-- Plugins {{{1
require("lazy").setup(
	{
		-- Libs {{{2
		{
			"nvim-lua/plenary.nvim",
			lazy = true,
		},
		-- }}}

		-- UIs {{{2
		{
			"nvim-tree/nvim-web-devicons",
			lazy = true,
		},
		{
			"stevearc/dressing.nvim",
			lazy = true,
			init = function()
				vim.ui.select = function(...)
					require("lazy").load({ plugins = { "dressing.nvim" } })
					return vim.ui.select(...)
				end
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
					builtin = {
						border = config.borders,
					},
				},
			},
		},
		{
			"norcalli/nvim-colorizer.lua",
			opts = {},
			cmd = "ColorizerToggle",
		},
		{
			"hiphish/rainbow-delimiters.nvim",
			enabled = false,
			event = "VeryLazy",
			opts = {},
			config = function()
				local rainbow_delimiters = require("rainbow-delimiters")

				vimg.rainbow_delimiters = {
					-- defines how to perform the highlighting of delimiters
					-- global, local
					strategy = {
						[""] = rainbow_delimiters.strategy["global"],
					},
					-- defines what to match
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
					blacklist = {},
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
		{
			"utilyre/sentiment.nvim",
			event = "VeryLazy",
			init = function()
				-- `matchparen.vim` needs to be disabled manually in case of lazy loading
				vimg.loaded_matchparen = 1
			end,
			opts = {},
		},
		--}}}

		-- LSPs {{{2
		{
			"neovim/nvim-lspconfig",
			event = "VeryLazy",
			dependencies = {
				{
					"folke/neodev.nvim",
					enabled = false,
				},
			},
			config = function(_, opts)
				load_plugin_config("lsp")
			end,
		},
		{
			"kosayoda/nvim-lightbulb",
			event = "LspAttach",
			opts = {
				autocmd = {
					enabled = true,
				},
				priority = 20, -- priority of dap signs is 21
				sign = {
					enabled = true,
					text = config.icons.bulb,
				},
			},
		},
		{
			"Wansmer/symbol-usage.nvim",
			event = "LspAttach",
			opts = {
				hl = { link = "LspInlayHint" },
				vt_position = "end_of_line",
				references = { enabled = true, include_declaration = false },
				definition = { enabled = false },
				implementation = { enabled = true },
			},
			config = function(_, opts)
				local SymbolKind = lsp_protocol.SymbolKind
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
			"j-hui/fidget.nvim",
			event = "LspAttach",
			opts = {
				notification = {
					override_vim_notify = false,
				},
			},
		},
		-- }}}

		-- DAPs {{{2
		{
			"mfussenegger/nvim-dap",
			keys = {
				"<leader>dc",
				"<leader>db",
			},
			cmd = {
				"DapContinue",
				"DapToggleBreakpoint",
			},
			dependencies = {
				"rcarriga/nvim-dap-ui",
				"jbyuki/one-small-step-for-vimkind",
				{
					"theHamsta/nvim-dap-virtual-text",
					enabled = false,
					opts = {
						virt_text_pos = "eol",
					},
				},
			},
			config = function(self, opts)
				load_plugin_config("dap")
			end,
		},
		-- }}}

		-- TreeSitters {{{2
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
			},
			config = function(_, opts)
				local tsc = require("treesitter-context")
				tsc.setup(opts)

				keymap.set("n", "<leader>cj", function()
					tsc.go_to_context(vim.v.count1)
				end, {})

				set_hls({
					TreesitterContext = { link = "StatusLine" },
					TreesitterContextLineNumber = { link = "Tag" },
					-- TreesitterContextBottom = { underline = true },
				})
			end,
		},
		{
			-- "nvim-treesitter/nvim-treesitter-textobjects",
			"gh-liu/nvim-treesitter-textobjects",
			lazy = true,
			event = "VeryLazy",
			config = function(self, opts) end,
		},
		{
			"JoosepAlviste/nvim-ts-context-commentstring",
			event = "VeryLazy",
		},
		{
			"IndianBoy42/tree-sitter-just",
			ft = "just",
			opts = {},
		},
		-- }}}

		-- Diagnostics {{{2
		{
			"mfussenegger/nvim-lint",
			lazy = true,
			init = function(self)
				local linters_by_ft = self.opts.linters_by_ft
				autocmd("FileType", {
					pattern = vim.tbl_keys(linters_by_ft),
					callback = function(ev)
						autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
							callback = function()
								require("lint").try_lint()
							end,
							buffer = ev.buf,
						})
					end,
					desc = "setup nvim-lint for ft",
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

		-- Telescopes {{{2
		{
			"nvim-telescope/telescope.nvim",
			event = "VeryLazy",
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
				load_plugin_config("telescope")

				set_hls({ TelescopeBorder = { link = "FloatBorder" } })
				api.nvim_create_autocmd("User", { pattern = "TelescopePreviewerLoaded", command = "setlocal number" })
			end,
		},
		{
			"edolphin-ydf/goimpl.nvim",
			ft = "go",
			config = function()
				require("telescope").load_extension("goimpl")

				api.nvim_create_autocmd("LspAttach", {
					group = user_augroup("lsp_attach_goimpl"),
					callback = function(args)
						local bufnr = args.buf
						local client = lsp.get_client_by_id(args.data.client_id)
						if client and client.name == "gopls" then
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
		-- }}}

		-- Text Edit {{{2
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
			keys = { "<M-h>", "<M-j>", "<M-k>", "<M-l>" },
			config = function(self, opts)
				require("mini.move").setup({
					mappings = {
						-- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
						left = self.keys[1],
						down = self.keys[2],
						up = self.keys[3],
						right = self.keys[4],
						-- Move current line in Normal mode
						line_left = self.keys[1],
						line_down = self.keys[2],
						line_up = self.keys[3],
						line_right = self.keys[4],
					},
				})
			end,
		},
		{
			"numToStr/Comment.nvim",
			lazy = true,
			keys = {
				{ "gc", mode = { "n", "x" } },
				{ "gb", mode = { "n", "x" } },
			},
			opts = {
				ignore = "^$",
			},
		},
		{
			"echasnovski/mini.surround",
			keys = {
				-- Add surrounding in Normal and Visual modes
				{ "ys", mode = { "x", "n" } },
				-- Delete surrounding
				{ "ds", mode = { "n" } },
				-- Replace surrounding
				{ "cs", mode = { "n" } },
			},
			config = function(self, _)
				local keys = self.keys

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

						suffix_last = "", -- Suffix to search with "prev" method
						suffix_next = "", -- Suffix to search with "next" method
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
					-- Replace text with register
					prefix = "s",
					-- Whether to reindent new text to match previous indent
					reindent_linewise = true,
				},
				exchange = {
					-- Exchange text regions
					prefix = "cx",
					-- Whether to reindent new text to match previous indent
					reindent_linewise = true,
				},
				evaluate = {
					-- Evaluate text and replace with output
					prefix = "g=",
				},
				-- miltiply = {
				-- 	-- Multiply (duplicate) text
				-- 	prefix = "",
				-- },
				-- sort = {
				-- 	-- Sort text
				-- 	prefix = "",
				-- },
			},
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
			"tpope/vim-abolish",
			cmd = { "Abolish", "Subvert", "S" },
			keys = { "cr" },
		},
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
			cmd = { "Format", "FormatEnable", "FormatDisable" },
			opts = {
				formatters_by_ft = {
					go = { "goimports", "gofumpt" },
					zig = { "zigfmt" },
					rust = { "rustfmt" },
					lua = { "stylua" },
					sh = { "shfmt" },
					zsh = { "shfmt" },
					json = { "jq" },
					just = { "just" },
					proto = { "buf" },
				},
			},
			config = function(self, opts)
				opts.format_on_save = function(bufnr)
					-- Disable with a global or buffer-local variable
					if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
						return
					end
					return { timeout_ms = 500, lsp_fallback = true }
				end
				require("conform").setup(opts)

				do
					vim.api.nvim_create_user_command(self.cmd[2], function()
						vim.b.disable_autoformat = false
						vim.g.disable_autoformat = false
					end, {
						desc = "Re-enable autoformat-on-save",
					})

					vim.api.nvim_create_user_command(self.cmd[3], function(args)
						if args.bang then
							-- FormatDisable! will disable formatting just for this buffer
							vim.b.disable_autoformat = true
						else
							vim.g.disable_autoformat = true
						end
					end, {
						desc = "Disable autoformat-on-save",
						bang = true,
					})
				end

				vim.api.nvim_create_user_command(self.cmd[1], function(args)
					local range = nil
					if args.count ~= -1 then
						local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
						range = {
							start = { args.line1, 0 },
							["end"] = { args.line2, end_line:len() },
						}
					end
					require("conform").format({ async = true, lsp_fallback = true, range = range })
				end, { range = true })
			end,
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
			"junegunn/vim-easy-align",
			keys = {
				{ "ga", "<Plug>(EasyAlign)", mode = { "n", "x" } },
				{ "gl", "<Plug>(LiveEasyAlign)", mode = { "n", "x" } },
			},
			cmd = {
				"EasyAlign",
				"LiveEasyAlign",
			},
		},
		{
			"cshuaimin/ssr.nvim",
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
		-- }}}

		-- Motions {{{2
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
			keys = {
				{ "i", mode = { "o", "x" } },
				{ "a", mode = { "o", "x" } },
			},
			config = function(self, opts)
				local ai = require("mini.ai")
				ai.setup({
					n_lines = 300,
					search_method = "cover",
					custom_textobjects = {
						o = ai.gen_spec.treesitter({ a = { "@conditional.outer" }, i = { "@conditional.inner" } }, {}),
						f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
						c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }, {}),
					},
					silent = true,
					mappings = {
						-- Disable last variants.
						around_last = "",
						inside_last = "",
						-- Disable next variants.
						-- around_next = "",
						-- inside_next = "",
					},
				})
			end,
		},
		{
			"chaoren/vim-wordmotion",
			enabled = true,
			init = function()
				vimg.wordmotion_nomap = true
				vimg.wordmotion_prefix = ","

				-- user define
				vim.g.wordmotion_disable = true
			end,
			keys = {
				{
					"<leader>tw",
					function()
						vim.g.wordmotion_disable = not vim.g.wordmotion_disable
						if vim.g.wordmotion_disable then
							vim.keymap.del({ "n", "x", "o" }, "w")
							vim.keymap.del({ "n", "x", "o" }, "b")
							vim.keymap.del({ "n", "x", "o" }, "e")
							vim.keymap.del({ "x", "o" }, "iw")
							vim.keymap.del({ "x", "o" }, "aw")

							vim.notify("Disabled word motion", vim.log.levels.WARN)
						else
							vim.keymap.set({ "n", "x", "o" }, "w", "<Plug>WordMotion_w")
							vim.keymap.set({ "n", "x", "o" }, "b", "<Plug>WordMotion_b")
							vim.keymap.set({ "n", "x", "o" }, "e", "<Plug>WordMotion_e")
							vim.keymap.set({ "x", "o" }, "iw", "<Plug>WordMotion_iw")
							vim.keymap.set({ "x", "o" }, "aw", "<Plug>WordMotion_aw")

							vim.notify("Enabled word motion", vim.log.levels.WARN)
						end
					end,
					desc = "[T]oggle [W]ord motion",
				},
			},
		},
		-- }}}

		-- Completions {{{2
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
			config = function(self, opts)
				require("cmp_git").setup(opts)

				local cmp = require("cmp")
				---@diagnostic disable-next-line: missing-fields
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

						vim.o.showmatch = vim.g.minipairs_disable
					end,
					desc = "[T]oggle auto [P]airs",
				},
			},
			config = function(self, opts)
				local pairs = require("mini.pairs")
				pairs.setup()

				local group = user_augroup("mini_pairs")
				autocmd("FileType", {
					group = group,
					pattern = { "zig" },
					callback = function(ev)
						local buf = ev.buf
						pairs.map_buf(buf, "i", "|", { action = "closeopen", pair = "||", register = { cr = false } })
					end,
					desc = "set pairs for zig",
				})
				autocmd("FileType", {
					group = group,
					pattern = { "rust" },
					callback = function(ev)
						local buf = ev.buf
						pairs.map_buf(buf, "i", "|", { action = "closeopen", pair = "||", register = { cr = false } })

						pairs.map_buf(buf, "i", "<", { action = "open", pair = "<>", register = { cr = false } })
						pairs.map_buf(buf, "i", ">", { action = "close", pair = "<>", register = { cr = false } })
					end,
					desc = "set pairs for rust",
				})
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
				local exit = function()
					api.nvim_buf_delete(fugitivebuf, { force = true })
				end
				keymap.set("n", "<leader>gg", function()
					if fugitivebuf > 0 then
						exit()
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

						keymap.set("n", "q", function()
							exit()
						end, { buffer = fugitivebuf })
					end,
				})
				-- }}}

				set_cmds({
					GUndoLastCommit = [[:G reset --soft HEAD~]],
					GDiscardChanges = [[:G reset --hard]],
				})
				set_cmds({
					Gdiffsplit3 = function(t)
						vim.cmd([[ tabnew % ]])
						-- The windows layout:
						-- Top-left: "ours" corresponding to the HEAD.
						-- Top-center: "base" corresponding to the common ancestor of main and merge-branch.
						-- Top-right: "theirs" corresponding to the tip of merge-branch.
						-- Bottom: the working copy.

						-- starts a diff between the current file and the object `:1`
						-- the doc states that `:1:%` corresponds to the current file's common ancestor during a conflict
						-- with % indicating the current file, which the default when omitted
						vim.cmd("Gdiffsplit :1")
						-- starts a vertical diff between the current file and all its direct ancestors
						vim.cmd("Gvdiffsplit!")
					end,
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
			"rbong/vim-flog",
			init = function(self)
				vim.g.flog_use_internal_lua = 1
				vim.g.flog_default_opts = { max_count = 2000 }
				vim.g.flog_permanent_default_opts = { date = "format:%Y-%m-%d %H:%m" }

				vim.keymap.set("ca", "F", "Flog", {})
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
					flogBranch9 = { fg = config.colors.green },
				})
			end,
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
					signcolumn = true,
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
						-- stage
						map("n", "<leader>gS", gs.stage_buffer, { desc = "Stage buffer" })
						map("n", "<leader>gs", gs.stage_hunk, { desc = "Stage hunk" })
						map("v", "<leader>gs", function()
							gs.stage_hunk({ fn.line("."), fn.line("v") })
						end, { desc = "Stage hunk" })

						-- reset
						map("n", "<leader>gR", gs.reset_buffer, { desc = "Reset buffer" })
						map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset hunk" })
						map("v", "<leader>gr", function()
							gs.reset_hunk({ fn.line("."), fn.line("v") })
						end, { desc = "Reset hunk of selection" })

						map("n", "<leader>gd", gs.diffthis)
						map("n", "<leader>gD", function()
							gs.diffthis("~")
						end)
						map("n", "<leader>gb", gs.blame_line)
						map("n", "<leader>gp", gs.preview_hunk)
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
			"ruifm/gitlinker.nvim",
			keys = { "<leader>gy" },
			opts = {},
		},
		{
			"akinsho/git-conflict.nvim",
			enabled = false,
			event = "VeryLazy",
			config = function()
				---@diagnostic disable-next-line: missing-fields
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

		-- Navigations  {{{
		{
			"echasnovski/mini.visits",
			event = "VeryLazy",
			opts = {},
			config = function(self, opts)
				require("mini.visits").setup(opts)

				do
					local vis = require("mini.visits")
					local lable_name = "core"
					vim.keymap.set("n", "<Leader>vv", function()
						vis.add_label(lable_name)
					end, { desc = "Add to core" })

					vim.keymap.set("n", "<Leader>vd", function()
						vis.remove_label(lable_name)
					end, { desc = "Remove from core" })

					vim.keymap.set("n", "<Leader>vl", function()
						vis.select_path(nil, { filter = lable_name })
					end, { desc = "Select core (cwd)" })

					vim.keymap.set("n", "<Leader>vL", function()
						vis.select_path("", { filter = lable_name })
					end, { desc = "Select core (all)" })

					local map_iterate_core = function(lhs, direction, desc)
						local opts = { filter = lable_name, wrap = true }
						local rhs = function()
							vis.iterate_paths(direction, vim.fn.getcwd(), opts)
						end
						vim.keymap.set("n", lhs, rhs, { desc = desc })
					end

					map_iterate_core("[[", "forward", "Core label (earlier)")
					map_iterate_core("]]", "backward", "Core label (later)")
					-- map_iterate_core("[{", "last", "Core label (earliest)")
					-- map_iterate_core("]}", "first", "Core label (latest)")
				end

				do
					local vis = require("mini.visits")
					local make_select_path = function(select_global, recency_weight)
						local sort = vis.gen_sort.default({ recency_weight = recency_weight })
						local select_opts = { sort = sort }
						return function()
							local cwd = select_global and "" or vim.fn.getcwd()
							vis.select_path(cwd, select_opts)
						end
					end

					local map_select = function(lhs, desc, ...)
						vim.keymap.set("n", lhs, make_select_path(...), { desc = desc })
					end

					map_select("<Leader>vr", "Select recent (all)", true, 1)
					map_select("<Leader>vR", "Select recent (cwd)", false, 1)
					map_select("<Leader>vy", "Select frecent (all)", true, 0.5)
					map_select("<Leader>vY", "Select frecent (cwd)", false, 0.5)
					map_select("<Leader>vf", "Select frequent (all)", true, 0)
					map_select("<Leader>vF", "Select frequent (cwd)", false, 0)
				end
			end,
		},
		{
			"echasnovski/mini.files",
			lazy = true,
			keys = {
				{
					"<leader>e",
					function()
						local MiniFiles = require("mini.files")
						if not MiniFiles.close() then
							local bufname = vim.api.nvim_buf_get_name(0)
							local path = vim.fn.fnamemodify(bufname, ":p")

							-- Open last if the buffer isn't valid.
							if path and vim.uv.fs_stat(path) then
								require("mini.files").open(bufname, false)
							else
								MiniFiles.open(MiniFiles.get_latest_path())
							end
						end
					end,
					desc = "File [E]xplorer",
				},
			},
			init = function()
				vim.api.nvim_create_autocmd("User", {
					pattern = "MiniFilesWindowOpen",
					callback = function(args)
						local win_id = args.data.win_id
						-- Customize window-local settings
						-- vim.wo[win_id].winblend = 50
						vim.api.nvim_win_set_config(win_id, { border = config.borders })

						local buf_id = args.data.buf_id
						local MiniFiles = require("mini.files")
						vim.keymap.set("n", "<CR>", function()
							MiniFiles.go_in()
						end, { buffer = buf_id })

						vim.keymap.set("n", "<leader><CR>", function()
							MiniFiles.synchronize()
						end, { buffer = buf_id })
					end,
				})
			end,
			opts = {
				mappings = {
					go_in = "<C-l>",
					go_out = "<C-h>",
				},
				options = {
					use_as_default_explorer = false,
				},
			},
		},
		{
			"Bekaboo/dropbar.nvim",
			enabled = true,
			event = "VeryLazy",
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
						-- ["q"] = function()
						-- 	cmd.quit()
						-- end,
					},
					win_configs = {
						border = config.borders,
					},
				},
			},
			config = function(self, opts)
				local symbols = {}
				local highlights = {}
				for key, value in pairs(config.icons.symbol_kinds) do
					symbols[key] = value.icon
					highlights["DropBarIconKind" .. key] = { link = value.hl }
				end
				opts.icons.kinds.symbols = symbols
				require("dropbar").setup(opts)

				keymap.set("n", "<leader>P", function()
					require("dropbar.api").pick()
				end)

				set_hls(highlights)
			end,
		},
		{
			"hedyhli/outline.nvim",
			cmd = { "Outline" },
			keys = { { "<leader>tt", "<cmd>Outline<CR>", desc = "Toggle Outline" } },
			opts = {
				outline_window = {
					-- Where to open the split window: right/left
					position = "left",
				},
				keymaps = {
					show_help = "g?",
					fold = "zc",
					unfold = "zo",
					fold_toggle = "za",
					fold_all = "zM",
					unfold_all = "zR",
					fold_toggle_all = "zA",
				},
			},
			config = function(self, opts)
				require("outline").setup(vim.tbl_extend("force", opts, {
					symbols = { icons = config.icons.symbol_kinds },
				}))
			end,
		},
		{
			"tpope/vim-projectionist",
			init = function(self)
				vim.g.projectionist_heuristics = {
					["go.mod"] = {
						["*.go"] = {
							alternate = "{}_test.go",
							type = "source",
							template = [[package {file|dirname|basename}]],
						},
						["*_test.go"] = {
							alternate = "{}.go",
							type = "test",
							template = [[package {file|dirname|basename}_test]],
						},
					},
				}

				-- api.nvim_create_autocmd("User", {
				-- 	pattern = "ProjectionistDetect",
				-- 	callback = function(ev)
				-- 		vim.notify("[Projections] detect!", vim.log.levels.INFO)
				-- 	end,
				-- })
			end,
			ft = { "go" },
			keys = {
				{ "<leader>aa", "<cmd>A<cr>" },
				{ "<leader>av", "<cmd>AV<cr>" },
			},
		},
		-- }}}

		-- UI Improvements {{{2
		{
			"szw/vim-maximizer",
			cmd = "MaximizerToggle",
			keys = {
				{
					"<leader>wm",
					function()
						vim.cmd.MaximizerToggle()
					end,
				},
			},
		},
		{
			"simeji/winresizer",
			init = function(self)
				-- disable the start key
				-- https://github.com/simeji/winresizer/pull/19#issuecomment-925097954
				-- vimg.winresizer_start_key = "<NOP>"

				vimg.winresizer_start_key = self.keys[1]
			end,
			keys = { "<leader>wr" },
			cmd = { "WinResizerStartResize" },
		},
		{
			"lewis6991/hover.nvim",
			keys = { "K", "gK" },
			config = function()
				require("hover").setup({
					init = function()
						require("hover.providers.lsp")
						require("hover.providers.man")
					end,
					preview_opts = {
						border = config.borders,
					},
					preview_window = false,
					title = true,
				})

				load_plugin_config("hover")

				-- Setup keymaps
				keymap.set("n", "K", require("hover").hover, { desc = "hover.nvim" })
				keymap.set("n", "gK", require("hover").hover_select, { desc = "hover.nvim (select)" })
			end,
		},
		{
			"mbbill/undotree",
			init = function()
				vimg.undotree_WindowLayout = 2
				vimg.undotree_DiffAutoOpen = 1
				vimg.undotree_ShortIndicators = 1
				vimg.undotree_SetFocusWhenToggle = 1
			end,
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
		},
		-- }}}

		-- Misc {{{2
		{
			"tpope/vim-repeat",
			event = "VeryLazy",
		},
		{
			"tpope/vim-rsi",
			init = function(self)
				vimg.rsi_no_meta = 1
			end,
			event = "VeryLazy",
		},
		{
			"tpope/vim-eunuch",
			enabled = true,
			cmd = {
				"SudoEdit",
				"SudoWrite",
			},
		},
		{
			"tpope/vim-sleuth",
			event = "VeryLazy",
		},
		{
			"tpope/vim-unimpaired",
			keys = { "yo", "[", "]" },
		},
		{
			"tpope/vim-dispatch",
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
			"tpope/vim-obsession",
			cmd = { "Obsession" },
		},
		{
			"akinsho/toggleterm.nvim",
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
			"pwntester/octo.nvim",
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
		{
			"famiu/bufdelete.nvim",
			cmd = { "Bdelete", "Bwipeout" },
			keys = {
				{
					"<leader>bd",
					function()
						require("bufdelete").bufdelete(0, false)
					end,
					desc = "Delete Buffer",
				},
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
			lazy = true,
			event = { "BufRead Cargo.toml" },
			init = function()
				api.nvim_create_autocmd("BufRead", {
					group = api.nvim_create_augroup("UserSetCargoCmpSource", { clear = true }),
					pattern = "Cargo.toml",
					callback = function()
						local cmp = require("cmp")
						---@diagnostic disable-next-line: missing-fields
						cmp.setup.buffer({ sources = { { name = "crates" } } })
					end,
				})

				vim.api.nvim_create_autocmd("BufRead", {
					pattern = "Cargo.toml",
					callback = function()
						local actions = require("crates.actions")

						local command = "crates.run_action"
						vim.lsp.commands[command] = function(cmd, ctx)
							local action = actions.get_actions()[cmd.data]
							if action then
								vim.api.nvim_buf_call(ctx.bufnr, action)
							end
						end
						local api = vim.api
						local server = require("liu.plugins.lsp2").server({
							capabilities = {
								codeActionProvider = true,
							},
							handlers = {
								---@param params lsp.CodeActionParams
								["textDocument/codeAction"] = function(_, params)
									local function format_title(name)
										return name:sub(1, 1):upper() .. name:gsub("_", " "):sub(2)
									end

									local code_actions = {}
									for key, action in pairs(actions.get_actions()) do
										table.insert(code_actions, {
											title = format_title(key),
											kind = "refactor.rewrite",
											command = command,
											data = key,
										})
									end
									return code_actions
								end,
							},
						})
						vim.lsp.start({ name = "crates_ls", cmd = server })
					end,
				})
			end,
			config = function()
				require("crates").setup({
					popup = {
						border = config.borders,
					},
					src = {
						cmp = { enabled = true },
					},
				})
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

vim.o.viewoptions = "folds,cursor"

vim.o.completeopt = "menu,menuone,noselect"

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

vim.o.scrolloff = 3

vim.o.cursorline = true

vim.o.splitright = true
vim.o.splitbelow = false

cmd([[
	set guicursor=n-v:block,i-c-ci-ve:ver25,r-cr:hor20,o:hor50
	  \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
	  \,sm:block-blinkwait175-blinkoff150-blinkon175
]])
-- }}}

-- Search {{{2
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
vim.o.timeoutlen = 350
vim.o.updatetime = 300
-- }}}

-- wrap {{{2
vim.o.wrap = false
vim.o.whichwrap = "b,s,<,>,h,l"
-- }}}

-- Folding {{{2
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
-- Filling `foldtext` with space
vim.opt.fillchars:append("fold: ")
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

-- Avoid showing the intro when starting Neovim
vim.opt.shortmess:append("I")

autocmd("BufEnter", {
	group = user_augroup("disable_newline_comment"),
	callback = function()
		vim.opt.formatoptions:remove({ "c", "r", "o" })
	end,
	desc = "Disable New Line Comment",
})
-- }}}

-- Remaps {{{1
local mapopts = { silent = true, noremap = true }
local setmap = function(mode, lhs, rhs, opts)
	opts = opts or mapopts
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

-- appen ;/, at the eol {{{3
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
setmap({ "n", "x", "o" }, "H", "^")
setmap({ "n", "x", "o" }, "L", "$")

-- Keep cursor in the center
setmap("n", "n", "nzzzv")
setmap("n", "N", "Nzzzv")
setmap("n", "<C-d>", "<C-d>zz")
setmap("n", "<C-u>", "<C-u>zz")
-- }}}

-- QF {{{2
setmap("n", "<leader>cc", "<cmd>try | cclose | lclose | catch | endtry <cr>")

-- setmap("n", "[q", "<cmd>try | cprev | catch | silent! clast | catch | endtry<cr>zv")
-- setmap("n", "]q", "<cmd>try | cnext | catch | silent! cfirst | catch | endtry<cr>zv")

-- setmap("n", "[l", ":lprev<cr>")
-- setmap("n", "]l", ":lnext<cr>")

-- Toggle the quickfix/loclist window. {{{3
-- When toggling these, ignore error messages and restore the cursor to the original window when opening the list.
local silent_mods = { mods = { silent = true, emsg_silent = true } }
vim.keymap.set("n", "<leader>xq", function()
	if vim.fn.getqflist({ winid = 0 }).winid ~= 0 then
		vim.cmd.cclose(silent_mods)
	elseif #vim.fn.getqflist() > 0 then
		local win = vim.api.nvim_get_current_win()
		vim.cmd.copen(silent_mods)
		if win ~= vim.api.nvim_get_current_win() then
			vim.cmd.wincmd("p")
		end
	end
end, { desc = "Toggle quickfix list" })
vim.keymap.set("n", "<leader>xl", function()
	if vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 then
		vim.cmd.lclose(silent_mods)
	elseif #vim.fn.getloclist(0) > 0 then
		local win = vim.api.nvim_get_current_win()
		vim.cmd.lopen(silent_mods)
		if win ~= vim.api.nvim_get_current_win() then
			vim.cmd.wincmd("p")
		end
	end
end, { desc = "Toggle location list" })
-- }}}
-- }}}

-- Buffers {{{
-- setmap("n", "[b", "<cmd>bprevious<cr>")
-- setmap("n", "]b", "<cmd>bnext<cr>")

-- switch to alternate file
setmap("n", "<leader>bb", "<C-^>")
-- }}}

-- Tabs {{{2
setmap("n", "<C-w>O", ":tabonly<CR>")
-- }}}

-- Abbrev{{{2
local opts = {
	expr = true,
	desc = "fixing that stupid typo when trying to [save]exit",
	noremap = true,
}
setmap("ca", "W", "((getcmdtype()  is# ':' && getcmdline() is# 'W')?('w'):('W'))", opts)
setmap("ca", "Q", "((getcmdtype()  is# ':' && getcmdline() is# 'Q')?('q'):('Q'))", opts)

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
setmap("n", "y<C-g>", ":<C-U>let @+ = expand('%:p')<CR>", { noremap = true })
-- }}}

-- }}}

-- Cmds {{{1
vim.api.nvim_create_user_command("Scratch", function()
	vim.cmd("bel 10new")
	local buf = vim.api.nvim_get_current_buf()
	for name, value in pairs({
		filetype = "scratch",
		buftype = "nofile",
		bufhidden = "hide",
		swapfile = false,
		modifiable = true,
	}) do
		vim.api.nvim_set_option_value(name, value, { buf = buf })
	end
end, { desc = "Open a scratch buffer", nargs = 0 })

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

api.nvim_create_user_command("R", function(opts)
	if #opts.fargs < 2 then
		vim.print("Arguments required.")
	end
	local old = vim.fn.getreg("r")

	vim.cmd([[redir @r]])
	local cmd = table.concat(opts.fargs, " ")
	vim.cmd("silent " .. cmd)
	vim.cmd([[redir END]])

	vim.cmd([[vertical new | normal "rp]])

	vim.fn.setreg("r", old)
end, {
	nargs = "*",
	desc = "Save the Output of Vim Command To a Empty Buffer",
})

api.nvim_create_user_command("Count", function(opts)
	local pattern = opts.args
	if #pattern == 0 then
		pattern = vim.fn.expand("<cword>")
	end
	local range = "%"
	if opts.line1 ~= opts.line2 then
		range = tostring(opts.line1) .. "," .. tostring(opts.line2)
	end
	vim.cmd(range .. "s/" .. pattern .. "//gn")
end, {
	nargs = "*",
	range = true,
	desc = "Count the Occurrences of a Pattern",
})
-- }}}

-- Autocmds {{{1
autocmd("TextYankPost", {
	group = user_augroup("highlight_yank"),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({
			timeout = vim.o.updatetime,
			priority = vim.highlight.priorities.user + 1,
		})
	end,
	desc = "Highlight when yanking",
})

autocmd("VimResized", {
	group = user_augroup("resize_splits"),
	command = "wincmd =",
	desc = "Equalize Splits",
})

autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
	group = user_augroup("checktime"),
	callback = function()
		-- normal buffer
		if vim.o.bt == "" then
			cmd("checktime")
		end
	end,
	desc = "Update file when there are changes",
})

-- autocmd("BufWritePre", {
-- 	command = "%s/\\s\\+$//e",
-- 	desc = "Trim Trailing",
-- })

autocmd("ModeChanged", {
	group = user_augroup("switch_highlight_when_searching"),
	callback = function()
		local cmdtype = fn.getcmdtype()
		if cmdtype == "/" or cmdtype == "?" then
			vim.opt.hlsearch = true
		else
			vim.opt.hlsearch = false
		end
	end,
	desc = "Highlighting matched words when searching",
})

-- :h last-position-jump
-- autocmd("BufReadPost", {
-- 	group = user_augroup("last_loc"),
-- 	callback = function(ev)
-- 		if vim.b.disable_jump_to_last_postion then
-- 			return true
-- 		end
-- 		local mark = api.nvim_buf_get_mark(ev.buf, '"')
-- 		local lcount = api.nvim_buf_line_count(ev.buf)
-- 		if mark[1] > 0 and mark[1] <= lcount then
-- 			pcall(api.nvim_win_set_cursor, 0, mark)
-- 		end
-- 		-- if fn.line("'\"") > 1 and fn.line("'\"") <= fn.line("$") then
-- 		-- 	cmd('normal! g`"')
-- 		-- end
-- 	end,
-- 	desc = "Go To The Last Cursor Position",
-- })

autocmd("BufWinEnter", {
	group = user_augroup("open_help_in_right_split"),
	pattern = { "*.txt" },
	callback = function(ev)
		if vim.o.filetype == "help" then
			cmd.wincmd("L")

			vim.keymap.set("n", "<leader>tt", ":wincmd T<CR>", { buffer = ev.buf })
		end
	end,
	desc = "Open help file in right split",
})

autocmd({ "BufWritePre" }, {
	group = user_augroup("auto_create_dir"),
	callback = function(event)
		if event.match:match("^%w%w+://") then
			return
		end
		local file = vim.loop.fs_realpath(event.match) or event.match
		vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
	end,
})

autocmd({ "TermOpen" }, {
	group = user_augroup("term_map"),
	pattern = "term://*",
	callback = function(event)
		local opts = { buffer = event.buf }
		vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
		vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
		vim.keymap.set("t", "<C-h>", [[<Cmd>wincmd h<CR>]], opts)
		vim.keymap.set("t", "<C-j>", [[<Cmd>wincmd j<CR>]], opts)
		vim.keymap.set("t", "<C-k>", [[<Cmd>wincmd k<CR>]], opts)
		vim.keymap.set("t", "<C-l>", [[<Cmd>wincmd l<CR>]], opts)
		vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
	end,
})

autocmd("OptionSet", {
	group = user_augroup("option_set_wrap"),
	pattern = "wrap",
	callback = function(ev)
		-- vim.print(vim.v.option_new)
		local buffer = vim.api.nvim_get_current_buf()
		if vim.v.option_new then
			vim.keymap.set("n", "j", "gj", { buffer = buffer })
			vim.keymap.set("n", "k", "gk")
		else
			-- vim.keymap.del("n", "j")
			-- vim.keymap.del("n", "k")
			pcall(vim.keymap.del, "n", "j", { buffer = buffer })
			pcall(vim.keymap.del, "n", "k", { buffer = buffer })
		end
	end,
	desc = "OptionSetWrap",
})

local enable_view = function(buf)
	return not vim.b.disable_view
		and api.nvim_buf_get_name(buf) ~= ""
		and api.nvim_get_option_value("buftype", { buf = buf }) == ""
end
local view_group = user_augroup("auto_view")
autocmd({ "BufWinLeave", "BufWritePre", "QuitPre" }, {
	group = view_group,
	callback = function(ev)
		if enable_view(ev.buf) then
			vim.cmd([[mkview 9]])
		end
	end,
	desc = "auto mkview",
})
autocmd({ "BufRead" }, {
	group = view_group,
	callback = function(ev)
		if enable_view(ev.buf) then
			vim.cmd([[silent! loadview 9]])
		end
	end,
	nested = true,
	desc = "auto loadview",
})

local set_cursorline = user_augroup("set_cursorline")
autocmd({ "InsertLeave" }, {
	group = set_cursorline,
	command = "set cursorline",
	desc = "set cursorline",
})
autocmd({ "InsertEnter" }, {
	group = set_cursorline,
	command = "set nocursorline",
	desc = "set nocursorline",
})

-- }}}

-- Diagnostic {{{1
-- https://neovim.io/doc/user/diagnostic.html
local diagnostic = vim.diagnostic
local min_serverity = diagnostic.severity.INFO
local opts = {
	underline = { severity = { min = min_serverity } },
	signs = {
		severity = { min = min_serverity },
		text = config.icons.diagnostics,
	},
	float = { source = true, border = config.borders, show_header = false },
	severity_sort = true,
	virtual_text = false,
	update_in_insert = false,
}
diagnostic.config(opts)

vim.g.disgnostic_sign_disable = false
keymap.set("n", "<leader>td", function()
	vim.g.disgnostic_sign_disable = not vim.g.disgnostic_sign_disable
	local opts = vim.deepcopy(opts)
	if vim.g.disgnostic_sign_disable then
		opts.signs = false
	end
	diagnostic.config(opts)
end)
keymap.set("n", "<leader>dp", diagnostic.open_float)
-- keymap.set("n", "<leader>dq", diagnostic.setloclist)
local diagnostic_goto = function(next, severity)
	local go = next and diagnostic.goto_next or vim.diagnostic.goto_prev
	severity = severity and diagnostic.severity[severity] or nil
	return function()
		go({ severity = severity })
	end
end
setmap("n", "]d", diagnostic_goto(true))
setmap("n", "[d", diagnostic_goto(false))
setmap("n", "]e", diagnostic_goto(true, vim.diagnostic.severity.ERROR))
setmap("n", "[e", diagnostic_goto(false, vim.diagnostic.severity.ERROR))
setmap("n", "]w", diagnostic_goto(true, vim.diagnostic.severity.WARN))
setmap("n", "[w", diagnostic_goto(false, vim.diagnostic.severity.WARN))

local diagnostic_icons = config.icons.diagnostics
fn.sign_define("DiagnosticSignError", { text = diagnostic_icons.ERROR, texthl = "DiagnosticSignError" })
fn.sign_define("DiagnosticSignWarn", { text = diagnostic_icons.WARN, texthl = "DiagnosticSignWarn" })
fn.sign_define("DiagnosticSignInfo", { text = diagnostic_icons.INFO, texthl = "DiagnosticSignInfo" })
fn.sign_define("DiagnosticSignHint", { text = diagnostic_icons.HINT, texthl = "DiagnosticSignHint" })
-- }}}

-- Lsp {{{1
local ms = lsp_protocol.Methods

-- Log Levels {{{2
lsp.set_log_level("OFF")

local levels = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF" }
api.nvim_create_user_command("LspSetLogLevel", function(opts)
	local level = unpack(opts.fargs)
	lsp.set_log_level(level)
	vim.notify("Set: " .. level, vim.log.levels.WARN)
end, {
	desc = "Set Lsp Log Level",
	nargs = 1,
	complete = function()
		return levels
	end,
})
-- }}}

-- keymaps {{{2
autocmd("LspAttach", {
	group = user_augroup("lsp_keymaps"),
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

		nmap("gD", lsp.buf.declaration, "[G]oto [D]eclaration")

		-- nmap("gd", lsp.buf.definition, "[G]oto [D]efinition")

		-- nmap("gy", lsp.buf.type_definition, "[G]oto T[y]pe Definition")

		-- nmap("gr", lsp.buf.references, "[G]oto [R]eferences")

		-- nmap("gi", lsp.buf.implementation, "[G]oto [I]mplementation")

		-- nmap("K", lsp.buf.hover, "Hover Documentation")

		keymap.set("i", "<C-k>", lsp.buf.signature_help, { buffer = bufnr, desc = "Signature Documentation" })
	end,
})
-- }}}

-- workspace {{{2
autocmd("LspAttach", {
	group = user_augroup("lsp_workspace"),
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
-- }}}

-- codelens {{{2
autocmd("LspAttach", {
	group = user_augroup("lsp_codelens"),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if client and client.supports_method("textDocument/codeLens") then
			local bufnr = args.buf
			autocmd({ "CursorHold", "InsertLeave" }, {
				callback = function()
					lsp.codelens.refresh()
				end,
				buffer = bufnr,
			})
		end
	end,
})
-- }}}

-- inlayhint {{{2
autocmd("LspAttach", {
	group = user_augroup("lsp_inlayhint"),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if client and client.supports_method("textDocument/inlayHint") then
			local bufnr = args.buf

			local inlay_hint = lsp.inlay_hint.enable
			inlay_hint(bufnr, true)

			api.nvim_buf_create_user_command(bufnr, "InlayHintToggle", function(opts)
				inlay_hint(bufnr, nil)
			end, {})

			api.nvim_buf_create_user_command(bufnr, "InlayHintRefresh", function(opts)
				inlay_hint(bufnr, false)
				inlay_hint(bufnr, true)
			end, {})
		end
	end,
})
-- }}}

-- document highlight {{{2
local util = lsp.util

---@param is_closer function (x,y) x is before y
local function move_to_highlight(is_closer)
	local win = api.nvim_get_current_win()
	local lnum, col = unpack(api.nvim_win_get_cursor(win))
	lnum = lnum - 1
	local cursor = {
		start = { line = lnum, character = col },
	}

	local params = util.make_position_params()
	local responses = lsp.buf_request_sync(0, ms.textDocument_documentHighlight, params)
	if not responses then
		return
	end
	local closest = nil
	for _, resp in pairs(responses) do
		local result = resp.result or {}
		for _, highlight in pairs(result) do
			local range = highlight.range
			local range_start = range.start
			local range_end = range["end"]
			local cursor_inside_range = (
				range_start.line <= lnum
				and range_end.line >= lnum
				and range_start.character < col
				and range_end.character > col
			)
			if
				not cursor_inside_range
				and is_closer(cursor, range)
				and (closest == nil or is_closer(range, closest))
			then
				closest = range
			end
		end
	end
	if closest then
		api.nvim_win_set_cursor(win, { closest.start.line + 1, closest.start.character })
	end
end

autocmd("LspAttach", {
	group = user_augroup("lsp_document_highlight"),
	callback = function(args)
		local client = lsp.get_client_by_id(args.data.client_id)
		if client and client.supports_method("textDocument/documentHighlight") then
			local bufnr = args.buf

			local aug = api.nvim_create_augroup("liu_lsp_document_highlight", {
				clear = false,
			})

			do
				api.nvim_clear_autocmds({
					buffer = bufnr,
					group = aug,
				})
				api.nvim_create_autocmd({ "CursorHold" }, {
					group = aug,
					buffer = bufnr,
					callback = function()
						lsp.buf.document_highlight()
					end,
				})
				api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
					group = aug,
					buffer = bufnr,
					callback = function()
						lsp.buf.clear_references()
					end,
				})
			end

			do
				-- x is before y
				local function is_before(x, y)
					if x.start.line < y.start.line then
						return true
					elseif x.start.line == y.start.line then
						return x.start.character < y.start.character
					else
						return false
					end
				end

				local function next_highlight()
					return move_to_highlight(is_before)
				end

				local function prev_highlight()
					return move_to_highlight(function(x, y)
						return is_before(y, x)
					end)
				end
				vim.keymap.set("n", "]v", next_highlight, { buffer = bufnr })
				vim.keymap.set("n", "[v", prev_highlight, { buffer = bufnr })
			end

			autocmd("LspDetach", {
				group = aug,
				callback = function()
					api.nvim_clear_autocmds({
						group = aug,
						buffer = bufnr,
					})
					vim.keymap.del("n", "]v", { buffer = bufnr })
					vim.keymap.del("n", "[v", { buffer = bufnr })
				end,
				buffer = bufnr,
			})
		end
	end,
})
-- }}}

-- handlers {{{2
local handlers = lsp.handlers

local old_hover = handlers[ms.textDocument_hover]
local old_signature = handlers[ms.textDocument_signatureHelp]
handlers[ms.textDocument_hover] = lsp.with(old_hover, { border = config.borders })
handlers[ms.textDocument_signatureHelp] = lsp.with(old_signature, { border = config.borders })

local old_rename = handlers[ms.textDocument_rename]
handlers[ms.textDocument_rename] = function(...)
	local function rename_notify(err, result, _, _)
		if err or not result then
			return
		end

		local changed_instances = 0
		local changed_files = 0

		local with_edits = result.documentChanges ~= nil
		for _, change in pairs(result.documentChanges or result.changes) do
			changed_instances = changed_instances + (with_edits and #change.edits or #change)
			changed_files = changed_files + 1
		end

		local message = string.format(
			"[LSP] Renamed %s instance%s in %s file%s.",
			changed_instances,
			changed_instances == 1 and "" or "s",
			changed_files,
			changed_files == 1 and "" or "s"
		)
		vim.notify(message)
	end
	old_rename(...)
	rename_notify(...)
end

-- handlers[ms.workspace_diagnostic_refresh] = function(_, result, ctx, _)
-- 	local ns = lsp.diagnostic.get_namespace(ctx.client_id)
-- 	diagnostic.reset(ns, api.nvim_get_current_buf())
-- 	vim.notify("Lsp Workspace Diagnostic Refresh.", vim.log.levels.WARN)
-- 	return true
-- end

-- }}}
-- }}}

-- vim: foldmethod=marker
