require("lazy").setup("liu.plugins.spec", {
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
		colorscheme = { vim.g.colors_name },
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
})
