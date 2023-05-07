local git = {
	{
		"tpope/vim-fugitive",
		event = "VeryLazy",
		config = function()
			-- toggle summary window
			local fugitivebuf = -1
			vim.keymap.set("n", "<leader>g", function()
				if fugitivebuf > 0 then
					vim.api.nvim_buf_delete(fugitivebuf, { force = true })
					fugitivebuf = -1
				else
					vim.cmd.G()
				end
			end, { silent = true })
			vim.api.nvim_create_autocmd("User", {
				pattern = { "FugitiveIndex" },
				callback = function(data)
					fugitivebuf = data.buf
					vim.api.nvim_create_autocmd("BufDelete", {
						callback = function()
							fugitivebuf = -1
						end,
						buffer = data.buf,
					})
					vim.cmd([[
					nmap <buffer> <Tab> =
					xmap <buffer> <Tab> =
					]])
				end,
			})

			-- Override the default fugitive commands to save the previous buffer before opening the log window.
			vim.cmd([[
			  command! -bang -nargs=? -range=-1 -complete=customlist,fugitive#LogComplete Gclog let g:fugitive_prevbuf=bufnr() | exe fugitive#LogCommand(<line1>,<count>,+"<range>",<bang>0,"<mods>",<q-args>, "c")
			  command! -bang -nargs=? -range=-1 -complete=customlist,fugitive#LogComplete GcLog let g:fugitive_prevbuf=bufnr() | exe fugitive#LogCommand(<line1>,<count>,+"<range>",<bang>0,"<mods>",<q-args>, "c")
			  command! -bang -nargs=? -range=-1 -complete=customlist,fugitive#LogComplete Gllog let g:fugitive_prevbuf=bufnr() | exe fugitive#LogCommand(<line1>,<count>,+"<range>",<bang>0,"<mods>",<q-args>, "l")
			  command! -bang -nargs=? -range=-1 -complete=customlist,fugitive#LogComplete GlLog let g:fugitive_prevbuf=bufnr() | exe fugitive#LogCommand(<line1>,<count>,+"<range>",<bang>0,"<mods>",<q-args>, "l")
			]])
			vim.api.nvim_create_user_command("GQuitLog", function()
				if vim.g.fugitive_prevbuf and (vim.bo.ft == "git" or vim.bo.ft == "qf") then
					vim.cmd.cclose()
					vim.cmd.lclose()
					vim.cmd.buffer(vim.g.fugitive_prevbuf)
				end
			end, {})

			vim.keymap.set("n", "<leader>W", "<cmd>Gw<CR>")

			set_alias({
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
						vim.keymap.set(mode, l, r, opts)
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
						gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, { desc = "Stage hunk" })

					map("n", "<leader>hR", gs.reset_buffer, { desc = "Reset buffer" })
					map("n", "<leader>hr", gs.reset_hunk, { desc = "Reset hunk" })
					map("v", "<leader>hr", function()
						gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, { desc = "Reset hunk" })

					map("n", "<leader>hd", gs.diffthis)
					map("n", "<leader>hD", function()
						gs.diffthis("~")
					end)

					map("n", "<leader>hp", gs.preview_hunk)
				end,
			})

			set_alias({
				GitsignsTCLB = [[:Gitsigns toggle_current_line_blame]],
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
			vim.g.git_messenger_no_default_mappings = true
			vim.g.git_messenger_floating_win_opts = { border = config.borders }
		end,
	},
	{
		"junegunn/gv.vim",
		cmd = { "GV" },
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

			vim.api.nvim_create_autocmd("User", {
				pattern = "GitConflictDetected",
				callback = function(args)
					vim.notify("[Git] Conflict detected!", vim.log.levels.WARN)

					local bufnr = args.buf
					local map = function(lhs, rhs)
						vim.keymap.set("n", lhs, rhs)
					end

					map("Co", "<Plug>(git-conflict-ours)")
					map("Ct", "<Plug>(git-conflict-theirs)")
					map("Cb", "<Plug>(git-conflict-both)")
					map("C0", "<Plug>(git-conflict-none)")
					map("[x", "<Plug>(git-conflict-prev-conflict)")
					map("]x", "<Plug>(git-conflict-next-conflict)")
				end,
			})

			vim.api.nvim_create_autocmd("User", {
				pattern = "GitConflictResolved",
				callback = function(args)
					vim.notify("[Git] Conflict resolved!", vim.log.levels.WARN)
				end,
			})
		end,
	},
}
return git
