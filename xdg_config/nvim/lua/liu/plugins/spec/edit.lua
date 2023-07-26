local edit = {
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
		config = function()
			require("treesj").setup({ use_default_keymaps = false, max_join_length = 300 })
		end,
	},
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			local npairs = require("nvim-autopairs")
			npairs.setup({
				-- enable_check_bracket_line = false,
				-- ignored_next_char = "[%w%.]",
				disable_filetype = { "TelescopePrompt" },
				fast_wrap = {
					map = "<M-l>",
					end_key = "l",
				},
			})

			-- npairs.add_rules(require("nvim-autopairs.rules.endwise-lua"))

			local Rule = require("nvim-autopairs.rule")
			npairs.add_rule(Rule("<", ">", "rust"))

			local cmp_autopairs = require("nvim-autopairs.completion.cmp")
			local cmp = require("cmp")
			-- cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
			local handlers = require("nvim-autopairs.completion.handlers")
			cmp.event:on(
				"confirm_done",
				cmp_autopairs.on_confirm_done({
					filetypes = {
						["*"] = {
							["("] = {
								kind = {
									cmp.lsp.CompletionItemKind.Function,
									cmp.lsp.CompletionItemKind.Method,
								},
								handler = handlers["*"],
							},
						},
					},
				})
			)
		end,
	},
	{
		"numToStr/Comment.nvim",
		event = "VeryLazy",
		config = function()
			require("Comment").setup({
				ignore = "^$",
			})

			local comment_ft = require("Comment.ft")
			comment_ft.set("lua", { "--%s", "--[[%s]]" })
			comment_ft.set("gomod", { "// %s" })
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
					normal_line = false,
					normal_cur_line = false,
					visual = false,
					visual_line = false,
					delete = "ds",
					change = "cs",
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
			vim.keymap.set("n", "s", require("substitute").operator, { noremap = true })
			vim.keymap.set("n", "ss", require("substitute").line, { noremap = true })
			vim.keymap.set("n", "S", require("substitute").eol, { noremap = true })
			vim.keymap.set("x", "s", require("substitute").visual, { noremap = true })
			-- range motion
			-- vim.keymap.set("n", "sr", require("substitute.range").operator, { noremap = true })
			-- vim.keymap.set("x", "sr", require("substitute.range").visual, { noremap = true })
			-- vim.keymap.set("n", "srr", require("substitute.range").word, { noremap = true })
			-- exchange
			vim.keymap.set("n", "cx", require("substitute.exchange").operator, { noremap = true })
			vim.keymap.set("n", "cxx", require("substitute.exchange").line, { noremap = true })
			vim.keymap.set("x", "X", require("substitute.exchange").visual, { noremap = true })
			vim.keymap.set("n", "cxc", require("substitute.exchange").cancel, { noremap = true })
		end,
	},
	{
		"junegunn/vim-easy-align",
		keys = {
			{ "ga", "<Plug>(EasyAlign)", mode = "x" },
		},
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
	{
		"dhruvasagar/vim-table-mode",
		-- event = "VeryLazy",
		cmd = { "TableModeToggle", "Tableize" },
		config = function()
			vim.g.table_mode_map_prefix = "<leader>t"
		end,
	},
	{ "tpope/vim-abolish", event = "VeryLazy" },
}

return edit
