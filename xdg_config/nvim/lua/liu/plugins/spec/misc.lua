local function getcwd()
	local cwd = vim.fn.getcwd(0)
	local dir = vim.fn.fnamemodify(cwd, ":~")
	return dir
end

return {
	{ "tpope/vim-repeat", event = "VeryLazy" },
	{ "tpope/vim-sleuth", event = "VeryLazy" },
	{
		"tpope/vim-dispatch",
		-- event = "VeryLazy",
		init = function()
			vim.g.dispatch_no_maps = 1
		end,
		cmd = { "Make", "Dispatch", "Start" },
	},
	{
		"tpope/vim-dadbod",
		cmd = { "DB" },
		ft = { "sql" },
		config = function()
			vim.cmd([[
			 nmap <expr> Q db#op_exec()
			 xmap <expr> Q db#op_exec()
			]])
		end,
	},
	{
		"lambdalisue/suda.vim",
		cmd = { "SudaRead", "SudaWrite" },
	},
	{
		"stevearc/oil.nvim",
		init = function()
			vim.api.nvim_create_user_command("OilSSH", function(opts)
				local url = opts.fargs[1]
				local r = string.gsub(url, ":/", "//")
				vim.cmd(string.format("Oil oil-ssh://%s", r))
			end, { nargs = 1 })
		end,
		cmd = { "Oil" },
		keys = {
			{
				"-",
				function()
					require("oil").open()
				end,
				desc = "[oil]Open parent directory",
				noremap = true,
				silent = true,
			},
		},
		config = function()
			require("oil").setup({
				keymaps = {
					["q"] = {
						callback = function()
							-- vim.cmd.bd()
							for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
								if vim.api.nvim_buf_get_name(bufnr):match("oil://.*") then
									vim.api.nvim_buf_delete(bufnr, { force = true })
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
		end,
	},
	{
		"akinsho/toggleterm.nvim",
		enabled = true,
		event = "VeryLazy",
		config = function()
			require("toggleterm").setup({
				-- open_mapping = "<leader>t",
				open_mapping = [[<c-\>]],
				insert_mappings = false,
				direction = "horizontal",
				float_opts = {
					border = config.borders,
					winblend = 3,
				},
				shade_terminals = false,
				highlights = {
					FloatBorder = {
						guifg = config.colors.blue,
					},
				},
				on_open = function(t) end,
				on_close = function(t) end,
				winbar = {
					enabled = false,
					-- name_formatter = function(term)
					-- 	return term.name
					-- end,
				},
			})

			local group = vim.api.nvim_create_augroup("UserToggleTermSettings", { clear = true })
			vim.api.nvim_create_autocmd("TermOpen", {
				pattern = "term://*toggleterm#*",
				callback = function()
					vim.cmd([[setl cmdheight=0]])

					local opts = { buffer = 0 }
					vim.keymap.set("t", "kk", [[<C-\><C-n>]], opts)
					vim.keymap.set("t", "<C-w>", [[<C-\><C-n><C-w>]], opts)
				end,
				group = group,
			})

			vim.api.nvim_create_autocmd({ "BufEnter" }, {
				pattern = "term://*toggleterm#*",
				callback = function()
					vim.cmd([[setl cmdheight=0]])
					if vim.fn.mode() == "n" then
						vim.cmd.startinsert()
					end
				end,
				group = group,
			})

			vim.api.nvim_create_autocmd("WinLeave", {
				pattern = "term://*toggleterm#*",
				callback = function()
					vim.cmd([[setl cmdheight=1]])
				end,
				group = group,
			})
		end,
	},
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
			vim.keymap.set("n", "K", require("hover").hover, { desc = "hover.nvim" })
			vim.keymap.set("n", "gK", require("hover").hover_select, { desc = "hover.nvim (select)" })
		end,
	},
	{
		"mbbill/undotree",
		-- event = "VeryLazy",
		-- cmd = { "UndotreeToggle" },
		keys = {
			{
				"<leader>u",
				vim.cmd.UndotreeToggle,
				desc = "Undotree: Toggle",
				noremap = true,
				silent = true,
			},
		},
		config = function()
			vim.g.undotree_WindowLayout = 2
			vim.g.undotree_DiffAutoOpen = 1
			vim.g.undotree_ShortIndicators = 1
			vim.g.undotree_SetFocusWhenToggle = 1
		end,
	},
	{
		"folke/persistence.nvim",
		enabled = false,
		event = "VeryLazy",
		config = function()
			require("persistence").setup()

			vim.api.nvim_create_user_command("LoadSession", function(opts)
				require("persistence").load({ last = true })
			end, {
				desc = "Load Persistence Session",
			})
		end,
	},
	{
		"stevearc/aerial.nvim",
		enabled = false,
		event = "VeryLazy",
		keys = {
			{
				"<leader>o",
				function()
					vim.cmd.AerialToggle()
				end,
			},
		},
		config = function()
			require("aerial").setup({
				backends = { "lsp", "treesitter", "man" },
				layout = {
					width = nil,
					max_width = { 40, 0.25 },
					min_width = 25,
					default_direction = "prefer_left",
				},
				close_on_select = true,
			})

			require("telescope").load_extension("aerial")
		end,
	},
	{
		"Bekaboo/dropbar.nvim",
		enabled = true,
		event = "VeryLazy",
		keys = {
			{
				"<leader>W",
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
						local fname = vim.api.nvim_buf_get_name(buf)
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

					return not vim.api.nvim_win_get_config(win).zindex
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
						local cursor = vim.api.nvim_win_get_cursor(menu.win)
						local component = menu.entries[cursor[1]]:first_clickable(cursor[2])
						if component then
							menu:click_on(component, nil, 1, "l")
						end
					end,
					["q"] = function()
						vim.cmd.quit()
					end,
				},
				win_configs = {
					border = config.borders,
				},
			},
		},
	},
	{
		"tomiis4/Hypersonic.nvim",
		cmd = "Hypersonic",
		opts = {},
		config = function(_, opts)
			require("hypersonic").setup(opts)
		end,
	},
	{
		-- dir = "~/dev/lua/hydra.nvim",
		"gh-liu/hydra.nvim",
		-- "anuvyklack/hydra.nvim",
		event = "VeryLazy",
		opts = {},
		config = function(_, opts)
			local Hydra = require("hydra")
			local cmd = require("hydra.keymap-util").cmd
			local pcmd = require("hydra.keymap-util").pcmd

			-- Hydra({
			-- 	name = "Windows",
			-- 	config = {
			-- 		invoke_on_body = true,
			-- 	},
			-- 	mode = "n",
			-- 	body = "<C-w>",
			-- 	heads = {
			-- 		{ ">", cmd("vertical resize +5") },
			-- 		{ "<", cmd("vertical resize -5") },
			-- 		{ "+", cmd("resize +5") },
			-- 		{ "-", cmd("resize -5") },

			-- 		{ "H", cmd("WinShift left") },
			-- 		{ "J", cmd("WinShift down") },
			-- 		{ "K", cmd("WinShift up") },
			-- 		{ "L", cmd("WinShift right") },

			-- 		{ "s", pcmd("split", "E36") },
			-- 		{ "<C-s>", pcmd("split", "E36"), { desc = false } },
			-- 		{ "v", pcmd("vsplit", "E36") },
			-- 		{ "<C-v>", pcmd("vsplit", "E36"), { desc = false } },

			-- 		{ "o", "<C-w>o", { exit = true, desc = "remain only" } },
			-- 		{ "<C-o>", "<C-w>o", { exit = true, desc = false } },

			-- 		{ "x", cmd("quit") },

			-- 		{ "q", nil, { exit = true, nowait = true } },
			-- 		{ "<Esc>", nil, { exit = true, nowait = true } },
			-- 	},
			-- })

			Hydra({
				name = "Folds",
				mode = { "n" },
				config = {
					color = "pink",
					hint = { type = "statusline" },
				},
				body = "z",
				heads = {
					-- { "a", "za", { desc = "-" } },
					{ "j", "zj", { desc = "↓" } },
					{ "k", "zk", { desc = "↑" } },

					{ "q", nil, { exit = true, nowait = true } },
					{ "<Esc>", nil, { exit = true, nowait = true } },
				},
			})
		end,
	},
	{
		"sindrets/winshift.nvim",
		-- event = "VeryLazy",
		cmd = { "WinShift" },
		opts = {},
	},
	{
		"famiu/bufdelete.nvim",
		-- event = "VeryLazy",
		keys = {
			{
				"<leader>q",
				"<cmd>Bdelete<cr>",
				desc = "Unload current buffer and delete it from the buffer list.",
				noremap = true,
				silent = true,
			},
		},
		cmd = { "Bdelete", "Bwipeout" },
	},
	{
		"ellisonleao/glow.nvim",
		opts = {
			border = config.borders,
		},
		-- config = true,
		cmd = "Glow",
	},
	{
		"epwalsh/obsidian.nvim",
		event = "VeryLazy",
		cond = function()
			local cwd = vim.fn.getcwd(0)
			local dir = vim.fn.fnamemodify(cwd, ":~") .. "/.obsidian"
			return vim.fn.isdirectory(dir) == 1
		end,
		opts = {
			dir = getcwd(),
			note_id_func = function(title)
				local suffix = ""
				if title ~= nil then
					suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
				else
					for _ = 1, 4 do
						suffix = suffix .. string.char(math.random(65, 90))
					end
				end
				return tostring(os.date("%Y%m%d@%H:%M:%S")) .. "-" .. suffix
			end,
			follow_url_func = function(url)
				vim.ui.open(url)
			end,
		},
		config = function(_, opts)
			require("obsidian").setup(opts)

			vim.keymap.set("n", "gf", function()
				if require("obsidian").util.cursor_on_markdown_link() then
					return "<cmd>ObsidianFollowLink<CR>"
				else
					return "gf"
				end
			end, { noremap = false, expr = true })
		end,
	},
	{
		"utilyre/sentiment.nvim",
		enabled = true,
		event = "VeryLazy",
		opts = {},
		init = function()
			-- vim.g.loaded_matchparen = 1
		end,
	},
	{
		"saecki/crates.nvim",
		event = { "BufRead Cargo.toml" },
		init = function()
			vim.api.nvim_create_autocmd("BufRead", {
				group = vim.api.nvim_create_augroup("UserSetCargoCmpSource", { clear = true }),
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
						return vim.fn.expand("%:t") == "Cargo.toml"
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
		"Olical/nfnl",
		ft = "fennel",
	},
}
