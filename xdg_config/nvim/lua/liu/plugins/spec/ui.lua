local ui = {
	{
		"nvim-tree/nvim-web-devicons",
		event = "VeryLazy",
	},
	{
		"stevearc/dressing.nvim",
		event = "VeryLazy",
		opts = {
			input = {
				enabled = true,
				border = config.borders,
				mappings = {
					n = {
						["<Esc>"] = "Close",
						["<CR>"] = "Confirm",
					},
					i = {
						["<C-c>"] = "Close",
						["<CR>"] = "Confirm",
					},
				},
				get_config = function(opts) end,
			},
			select = {
				enabled = true,
				backend = { "telescope", "builtin" },
				telescope = nil,
				builtin = {
					border = config.borders,
					mappings = {
						["<Esc>"] = "Close",
						["<C-c>"] = "Close",
						["<CR>"] = "Confirm",
					},
				},
				get_config = function(opts) end,
			},
		},
		config = function(_, opts)
			require("dressing").setup(opts)
		end,
	},
	{
		"norcalli/nvim-colorizer.lua",
		opts = {},
		cmd = "ColorizerToggle",
	},
	{
		"powerman/vim-plugin-AnsiEsc",
		cmd = "AnsiEsc",
	},
	{
		"szw/vim-maximizer",
		cmd = "MaximizerToggle",
	},
	{
		"rebelot/heirline.nvim",
		enabled = true,
		config = function()
			-- require("liu.config.statusline")
		end,
	},
	{
		"rcarriga/nvim-notify",
		enabled = false,
		event = "VeryLazy",
		config = function()
			vim.notify = require("notify")

			require("notify").setup({
				fps = 30,
				level = 1,
				max_height = function()
					return math.floor(vim.o.lines * 0.50)
				end,
				max_width = function()
					return math.floor(vim.o.columns * 0.45)
				end,
				on_open = function(win)
					vim.api.nvim_win_set_config(win, { focusable = false })
				end,
				stages = "fade",
				timeout = 150,
				icons = {
					DEBUG = config.debug_icons.bug,
					ERROR = config.icons.Error,
					WARN = config.icons.Warn,
					INFO = config.icons.Info,
					TRACE = "✎",
				},
			})

			set_hls({
				NotifyERRORBorder = { fg = config.colors.red },
				NotifyWARNBorder = { fg = config.colors.yellow },
				NotifyINFOBorder = { fg = config.colors.green },
				NotifyDEBUGBorder = { fg = config.colors.blue },
				NotifyTRACEBorder = { fg = config.colors.gray },

				NotifyERRORIcon = { link = "NotifyERRORBorder" },
				NotifyWARNIcon = { link = "NotifyWARNBorder" },
				NotifyINFOIcon = { link = "NotifyINFOBorder" },
				NotifyDEBUGIcon = { link = "NotifyDEBUGBorder" },
				NotifyTRACEIcon = { link = "NotifyTRACEBorder" },

				NotifyERRORTitle = { link = "NotifyERRORBorder" },
				NotifyWARNTitle = { link = "NotifyWARNBorder" },
				NotifyINFOTitle = { link = "NotifyINFOBorder" },
				NotifyDEBUGTitle = { link = "NotifyDEBUGBorder" },
				NotifyTRACETitle = { link = "NotifyTRACEBorder" },
			})
		end,
	},
	{
		"lewis6991/satellite.nvim",
		enabled = false,
		event = "VeryLazy",
		opts = {
			current_only = true,
			winblend = 50,
			zindex = 40,
			excluded_filetypes = {},
			width = 2,
			handlers = {
				search = {
					enable = false,
				},
				diagnostic = {
					enable = false,
					signs = { "-", "=", "≡" },
					min_severity = vim.diagnostic.severity.HINT,
				},
				gitsigns = {
					enable = true,
					signs = { -- can only be a single character (multibyte is okay)
						add = "│",
						change = "│",
						delete = "-",
					},
				},
				marks = {
					enable = true,
					show_builtins = false, -- shows the builtin marks like [ ] < >
				},
			},
		},
		config = function(_, opts)
			require("satellite").setup(opts)
			set_hls({
				MarkSV = { fg = config.colors.magenta },
			})
		end,
	},
	{
		"vigoux/notifier.nvim",
		event = "VeryLazy",
		config = function()
			require("notifier").setup({})

			set_hls({
				-- NotifierTitle = {},
				-- NotifierIcon = {},
				NotifierContent = { link = "LspInlayHint" },
				NotifierContentDim = { link = "LspInlayHint" },
			})
		end,
	},
}

return ui
