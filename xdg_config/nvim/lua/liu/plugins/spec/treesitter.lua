local ts = {
	{
		"nvim-treesitter/nvim-treesitter",
		event = "VeryLazy",
		build = ":TSUpdate",
		config = function()
			require("liu.treesitter")
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		enabled = true,
		event = "VeryLazy",
		config = function() end,
	},
	{
		"nvim-treesitter/nvim-treesitter-refactor",
		enabled = true,
		event = "VeryLazy",
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		event = "VeryLazy",
		config = function()
			require("treesitter-context").setup({
				enable = true,
				max_lines = 0,
				min_window_height = 0,
				line_numbers = true,
				multiline_threshold = 20,
				trim_scope = "outer",
				mode = "cursor",
				separator = nil,
				zindex = 20,
			})

			set_hls({
				TreesitterContext = { link = "StatusLine" },
				TreesitterContextLineNumber = { link = "Tag" },
				-- TreesitterContextBottom = { underline = true },
			})
		end,
	},
	{
		"nvim-treesitter/playground",
		enabled = false,
		cmd = "TSPlaygroundToggle",
	},
	{
		"theHamsta/nvim-treesitter-pairs",
		enabled = false,
		event = "VeryLazy",
		config = function()
			require("nvim-treesitter.configs").setup({
				pairs = {
					enable = true,
					disable = {},
					highlight_pair_events = {},
					highlight_self = false,
					goto_right_end = false,
					fallback_cmd_normal = "call matchit#Match_wrapper('',1,'n')",
					keymaps = {
						goto_partner = "%",
						delete_balanced = "X",
					},
					delete_balanced = {
						only_on_first_char = false,
						fallback_cmd_normal = nil,
						longest_partner = false,
					},
				},
			})
		end,
	},
	{
		url = "https://gitlab.com/HiPhish/nvim-ts-rainbow2",
		event = "VeryLazy",
		config = function()
			set_hls({
				TSRainbowRed = { fg = "#BF616A" },
				TSRainbowBlue = { fg = "#5E81AC" },
				TSRainbowCyan = { fg = "#8FBCBB" },
				TSRainbowGreen = { fg = "#A3BE8C" },
				TSRainbowOrange = { fg = "#D08770" },
				TSRainbowViolet = { fg = "#B48EAD" },
				TSRainbowYellow = { fg = "#EBCB8B" },
			})
			require("nvim-treesitter.configs").setup({
				rainbow = {
					enable = true,
					disable = {},
					query = "rainbow-parens",
					strategy = require("ts-rainbow.strategy.global"),
				},
			})
		end,
	},
	{
		"IndianBoy42/tree-sitter-just",
		ft = "just",
		opts = {},
	},
}
return ts
