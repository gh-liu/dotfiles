return {
	{ "tpope/vim-repeat", event = "VeryLazy" },
	{ "tpope/vim-sleuth", event = "VeryLazy" },
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
				"<leader>ww",
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
}
