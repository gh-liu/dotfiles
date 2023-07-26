local motion = {
	{
		"wellle/targets.vim",
		event = "VeryLazy",
		config = function()
			-- https://github.com/wellle/targets.vim#gtargets_seekranges
			-- Only consider targets around cursor
			vim.g.targets_seekRanges = "cc cr cb cB lc ac Ac lr lb ar ab lB Ar aB Ab AB"
		end,
	},
	{
		"chrisgrieser/nvim-various-textobjs",
		enabled = false,
		event = "VeryLazy",
		config = function()
			require("various-textobjs").setup({
				-- "small" textobjs (mostly characterwise textobjs)
				lookForwardSmall = 0,
				-- "big" textobjs (linewise textobjs & url textobj)
				lookForwardBig = 3,
				useDefaultKeymaps = false,
				disabledKeymaps = {},
			})
			local map = function(lhs, rhs)
				vim.keymap.set({ "o", "x" }, lhs, rhs)
			end

			map("u", '<cmd>lua require("various-textobjs").url()<CR>')
			-- map("?", '<cmd>lua require("various-textobjs").diagnostic()<CR>')
			-- map("%", '<cmd>lua require("various-textobjs").toNextClosingBracket()<CR>')

			-- map("is", '<cmd>lua require("various-textobjs").subword(true)<CR>')
			-- map("as", '<cmd>lua require("various-textobjs").subword(false)<CR>')

			map("iI", '<cmd>lua require("various-textobjs").indentation(true, true)<CR>')
			map("aI", '<cmd>lua require("various-textobjs").indentation(false, false)<CR>')
		end,
	},
	{
		"ggandor/leap.nvim",
		enabled = false,
		event = "VeryLazy",
		config = function()
			require("leap").opts = vim.tbl_extend("force", require("leap").opts, {
				-- stylua: ignore
				safe_labels = {  "n", "j", "k", "l", "h", "o", "d", "w", "e", "m", "b", "u", "y", "v", "r", "g", "t", "c", "x", "/", "z", "F", "N", "J", "K", "L", "H", "O", "D", "W", "E", "M", "B", "U", "Y", "V", "R", "G", "T", "C", "X", "?", "Z" },
				labels = { "n", "u", "t", "/", "F", "N", "L", "H", "M", "U", "G", "T", "?", "Z" },
				special_keys = {
					repeat_search = "<enter>",
					next_phase_one_target = "<enter>",
					next_target = { ";" },
					prev_target = { "," },
					next_group = "<space>",
					prev_group = "<tab>",
					multi_accept = "<enter>",
					multi_revert = "<backspace>",
				},
			})

			for _, maps in ipairs({
				{ { "n" }, "<leader>f", "<Plug>(leap-forward-to)", "Leap forward to" },
				{ { "n" }, "<leader>F", "<Plug>(leap-backward-to)", "Leap backward to" },
				-- { { "n", "x" }, "f", "<Plug>(leap-forward-to)", "Leap forward to" },
				-- { { "n", "x" }, "F", "<Plug>(leap-backward-to)", "Leap backward to" },
				-- { { "n", "x" }, "t", "<Plug>(leap-forward-till)", "Leap forward till" },
				-- { { "n", "x" }, "T", "<Plug>(leap-backward-till)", "Leap backward till" },
				-- { { "n", "x", "o" }, "gs", "<Plug>(leap-from-window)", "Leap from window" },
				-- { { "n", "x", "o" }, "gs", "<Plug>(leap-cross-window)", "Leap from window" },
			}) do
				local modes = maps[1]
				local lhs = maps[2]
				local rhs = maps[3]
				local desc = maps[4]
				vim.keymap.set(modes, lhs, rhs, { silent = true, desc = desc })
			end

			-- Greying out the search area
			-- set_hls({ LeapBackdrop = { fg = config.colors.gray } })

			vim.api.nvim_create_autocmd("User", {
				pattern = "LeapEnter",
				callback = function()
					-- vim.print("LeapEnter")
					vim.g.user_leap_status = 1
				end,
			})
			vim.api.nvim_create_autocmd("User", {
				pattern = "LeapLeave",
				callback = function()
					-- vim.print("LeapLeave")
					vim.g.user_leap_status = 0
				end,
			})

			-- linewise motions
			local function line_wise()
				local function get_line_starts(winid)
					local wininfo = vim.fn.getwininfo(winid)[1]
					local cur_line = vim.fn.line(".")
					-- Get targets.
					local targets = {}
					local lnum = wininfo.topline
					while lnum <= wininfo.botline do
						local fold_end = vim.fn.foldclosedend(lnum)
						-- Skip folded ranges.
						if fold_end ~= -1 then
							lnum = fold_end + 1
						else
							if lnum ~= cur_line then
								table.insert(targets, { pos = { lnum, 1 } })
							end
							lnum = lnum + 1
						end
					end
					-- Sort them by vertical screen distance from cursor.
					local cur_screen_row = vim.fn.screenpos(winid, cur_line, 1)["row"]
					local function screen_rows_from_cur(t)
						local t_screen_row = vim.fn.screenpos(winid, t.pos[1], t.pos[2])["row"]
						return math.abs(cur_screen_row - t_screen_row)
					end
					table.sort(targets, function(t1, t2)
						return screen_rows_from_cur(t1) < screen_rows_from_cur(t2)
					end)
					if #targets >= 1 then
						return targets
					end
				end

				local function leap_to_line()
					local winid = vim.api.nvim_get_current_win()
					require("leap").leap({
						target_windows = { winid },
						targets = get_line_starts(winid),
					})
				end

				vim.keymap.set("n", "<leader>ll", leap_to_line, { silent = true })
			end
			line_wise()
		end,
	},
	{
		"ggandor/flit.nvim",
		enabled = false,
		event = "VeryLazy",
		dependencies = {
			"ggandor/leap.nvim",
		},
		opts = {
			labeled_modes = "n",
		},
	},
	{
		"folke/flash.nvim",
		-- event = "VeryLazy",
		opts = {
			modes = {
				char = {
					enabled = false,
				},
			},
		},
		keys = {
			{
				"<leader>f",
				mode = { "n", "x", "o" },
				function()
					require("flash").jump({
						search = { forward = true, wrap = false, multi_window = true },
					})
				end,
				desc = "Forward search only",
			},
			{
				"<leader>F",
				mode = { "n", "x", "o" },
				function()
					require("flash").jump({
						search = { forward = false, wrap = false, multi_window = true },
					})
				end,
				desc = "Backward search only",
			},
			{
				"r",
				mode = "o",
				function()
					require("flash").remote()
				end,
				desc = "Remote Flash",
			},
			{
				"<leader>ll",
				mode = { "n" },
				function()
					require("flash").jump({
						search = { mode = "search" },
						highlight = { label = { after = { 0, 0 } } },
						pattern = "^",
					})
				end,
				desc = "Jump to a line",
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
		"chaoren/vim-wordmotion",
		event = "VeryLazy",
		init = function()
			vim.g.wordmotion_nomap = true
			vim.g.wordmotion_prefix = ","

			local ok, Hydra = pcall(require, "hydra")
			if ok then
				Hydra({
					name = "Quick words",
					config = {
						color = "pink",
						hint = { type = "statusline" },
					},
					mode = { "n", "x", "o" },
					body = "<leader>",
					heads = {
						{ "w", "<Plug>WordMotion_w", { desc = "WordMotion_w" } },
						{ "b", "<Plug>WordMotion_b", { desc = "WordMotion_b" } },
						{ "e", "<Plug>WordMotion_e", { desc = "WordMotion_e" } },
						{ "ge", "<Plug>WordMotion_ge", { desc = "WordMotion_ge" } },
						{ "aw", "<Plug>WordMotion_aw", { mode = { "x", "o" }, desc = false } },
						{ "iw", "<Plug>WordMotion_iw", { mode = { "x", "o" }, desc = false } },

						{ "q", nil, { exit = true, nowait = true } },
						{ "<Esc>", nil, { exit = true, nowait = true } },
					},
				})
			end
		end,
	},
}

return motion
