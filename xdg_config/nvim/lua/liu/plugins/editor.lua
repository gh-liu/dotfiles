local config = require("liu.user_config")
local api = vim.api
local fn = vim.fn

return {
	{
		"justinmk/vim-dirvish",
		enabled = true,
		init = function(self)
			vim.g.loaded_netrwPlugin = 1

			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "dirvish" },
				callback = function(ev)
					-- :h dirvish-mappings
					vim.keymap.set("n", "g<c-s>", "o", { remap = true, buffer = 0 })
					vim.keymap.set("n", "g<c-v>", "a", { remap = true, buffer = 0 })
					vim.keymap.set("v", "g<c-s>", "O", { remap = true, buffer = 0 })
					vim.keymap.set("v", "g<c-v>", "A", { remap = true, buffer = 0 })
				end,
			})
		end,
		config = function(self, opts)
			vim.cmd([[
			    command! -nargs=? -complete=dir Explore Dirvish <args>
			    command! -nargs=? -complete=dir Sexplore belowright split | silent Dirvish <args>
			    command! -nargs=? -complete=dir Vexplore leftabove vsplit | silent Dirvish <args>
			]])
		end,
	},
	{
		"echasnovski/mini.files",
		lazy = true,
		init = function()
			local g = vim.api.nvim_create_augroup("liu/mini.files/win_setup", { clear = true })
			api.nvim_create_autocmd("User", {
				pattern = "MiniFilesWindowOpen",
				group = g,
				callback = function(args)
					local win_id = args.data.win_id
					-- Customize window-local settings
					-- vim.wo[win_id].winblend = 50
					api.nvim_win_set_config(win_id, { border = config.borders })
				end,
			})

			api.nvim_create_autocmd("User", {
				pattern = "MiniFilesBufferCreate",
				group = g,
				callback = function(args)
					local buf = args.data.buf_id

					local MiniFiles = require("mini.files")

					-- disable blink.cmp
					vim.b[buf].completion = false

					do
						-- https://github.com/echasnovski/mini.nvim/issues/391
						-- set up ability to confirm changes with :w
						api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
						-- vim.b[buf].minivisits_disable = true

						-- api.nvim_buf_set_name(buf, string.format("mini.files-%s", vim.uv.hrtime()))
						-- api.nvim_create_autocmd("BufWriteCmd", {
						-- 	callback = MiniFiles.synchronize,
						-- 	buffer = buf,
						-- })
					end

					vim.keymap.set("n", "gx", function()
						vim.ui.open(MiniFiles.get_fs_entry().path)
					end, { buffer = buf, desc = "OS open" })

					vim.keymap.set("n", "<CR>", function()
						MiniFiles.go_in({ close_on_file = true })
					end, { buffer = buf })
					vim.keymap.set("n", "<leader><CR>", MiniFiles.synchronize, { buffer = buf })

					vim.keymap.set("n", "cd", function()
						local MiniFiles = require("mini.files")
						local path = MiniFiles.get_fs_entry().path
						MiniFiles.close()
						vim.cmd.lcd(path)
					end, { buffer = buf })

					vim.keymap.set("n", "g.", function()
						local MiniFiles = require("mini.files")
						local path = MiniFiles.get_fs_entry().path
						MiniFiles.close()
						vim.fn.feedkeys(": " .. path)
						vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<HOME>", true, true, true))
					end, { buffer = buf })

					vim.keymap.set("n", "yY", function()
						local minifiles = require("mini.files")
						local path = minifiles.get_fs_entry().path
						local p
						if vim.v.count > 0 then
							p = fn.fnamemodify(path, ":p")
						else
							p = fn.fnamemodify(path, ":.")
						end
						fn.setreg(vim.v.register, p)
						print(string.format([[copy "%s"]], p))
					end, { buffer = buf })

					local map_split = function(buf_id, lhs, direction)
						local rhs = function()
							local cur_target = MiniFiles.get_explorer_state().target_window
							local new_target = vim.api.nvim_win_call(cur_target, function()
								vim.cmd(direction .. " split")
								return vim.api.nvim_get_current_win()
							end)

							MiniFiles.set_target_window(new_target)

							MiniFiles.go_in({ close_on_file = true })
						end

						local desc = "Split " .. direction
						vim.keymap.set("n", lhs, rhs, { buffer = buf_id, desc = desc })
					end
					map_split(buf, "g<c-s>", "belowright horizontal")
					map_split(buf, "g<c-v>", "belowright vertical")

					-- vim-flagship {{{
					vim.cmd([[
						function! MinifilesReal(...) abort
							let file = a:0 ? a:1 : @%
							if file =~# '^\a\a\+:' || a:0 > 1
								return v:lua.MinifilesReal(file)
							else
								return fnamemodify(file, ':p' . (file =~# '[\/]$' ? '' : ':s?[\/]$??'))
							endif
						endfunction
					]])
					_G.MinifilesReal = function(file)
						local _, _, buf, relpath = file:find([[^minifiles://(%d+)/(.*)]])
						if relpath then
							return relpath .. "/"
						end
						return file
					end
					-- }}}
				end,
			})

			api.nvim_create_autocmd("User", {
				group = g,
				pattern = "MiniFilesExplorerOpen",
				callback = function()
					local MiniFiles = require("mini.files")
					MiniFiles.set_bookmark("~", "~", { desc = "Home directory" })
					MiniFiles.set_bookmark("w", vim.fn.getcwd, { desc = "Working directory" })
				end,
			})

			api.nvim_create_autocmd("User", {
				pattern = "MiniFilesActionDelete",
				group = g,
				callback = function(args)
					local fname = args.data.from
					local bufnr = fn.bufnr(fname)
					if bufnr > 0 then
						-- delte buffer
						-- require("mini.bufremove").delete(bufnr, false)
						if vim.api.nvim_buf_is_valid(bufnr) then
							vim.api.nvim_buf_call(bufnr, function()
								vim.cmd([[buf#]])
								vim.api.nvim_buf_delete(bufnr, { force = true })
							end)
						end
					end
				end,
			})
		end,
		keys = {
			{
				"<leader>e",
				function()
					local MiniFiles = require("mini.files")
					if not MiniFiles.close() then
						local bufname = api.nvim_buf_get_name(0)
						local is_dir = vim.fn.isdirectory(bufname) == 1
						local dirs = {}
						if is_dir then
							table.insert(dirs, bufname)
						else
							local file_not_valid = bufname == "" or vim.fn.filereadable(bufname) == 0
							if file_not_valid then
								-- vim.api.nvim_echo({
								-- 	{ "mini.files: ", "" },
								-- 	{ "buffer name not valid", "DiagnosticWarn" },
								-- }, false, {})
								bufname = vim.fs.normalize(vim.fn.getcwd(), {})
								table.insert(dirs, bufname)
							end
						end
						for dir in vim.fs.parents(bufname) do
							table.insert(dirs, dir)
						end

						local count = vim.v.count1
						local path = dirs[count]
						if count == 1 and vim.fn.isdirectory(bufname) == 0 then
							-- If it is a path to file, its parent directory is used as anchor
							-- while explorer will focus on the supplied file.
							MiniFiles.open(bufname, false)
						else
							MiniFiles.open(path, false)
						end
					end
				end,
				desc = "File [E]xplorer",
			},
			{
				"<leader>E",
				function()
					local MiniFiles = require("mini.files")
					if not MiniFiles.close() then
						local path = vim.fn.getcwd()
						MiniFiles.open(path, false)
					end
				end,
				desc = "File [E]xplorer",
			},
		},
		opts = {
			mappings = {
				go_in = "<C-l>",
				go_out = "<C-h>",
				-- Use `''` (empty string) to not create one.
				go_in_plus = "",
				go_out_plus = "",

				mark_set = "m",
				mark_goto = "`",
			},
			options = { use_as_default_explorer = false },
		},
	},
	{
		"echasnovski/mini.visits",
		event = "VeryLazy",
		opts = {},
		init = function()
			vim.api.nvim_create_autocmd("FileType", {
				pattern = {
					"gitcommit",
				},
				callback = function(ev)
					local buf = ev.buf
					vim.b[buf].minivisits_disable = true
				end,
			})

			local visit_cwd = function()
				return vim.fn.getcwd(-1, 0)
			end
			-- vim-flagship
			vim.api.nvim_create_autocmd("User", {
				pattern = "Flags",
				callback = function(args)
					vim.fn["Hoist"]("buffer", 11, function()
						local MiniVisits = require("mini.visits")
						local bufname = vim.fn.bufname()
						if #bufname == 0 then
							return ""
						end
						local labels = MiniVisits.list_labels(bufname, visit_cwd())
						if not labels or #labels == 0 then
							return ""
						end
						return "::" .. vim.fn.join(labels, ",")
					end)
				end,
			})

			do
				local label = "core"
				local hi_entry_add = function(entry, buf, line)
					local ns = vim.api.nvim_create_namespace(entry.path)
					local entry_name = entry.name
					vim.schedule(function()
						local row = line - 1
						local pos = vim.fn.searchpos(entry_name, "n")
						local col_start = pos[2] - 1
						vim.api.nvim_buf_set_extmark(buf, ns, row, col_start, {
							end_line = row,
							end_col = col_start + #entry_name,
							hl_group = "DiagnosticWarn",
						})
					end)
				end
				local hi_entry_del = function(entry, buf, line)
					local ns = vim.api.nvim_create_namespace(entry.path)
					vim.schedule(function()
						local row = line - 1
						vim.api.nvim_buf_clear_namespace(buf, ns, row, line)
					end)
				end
				vim.api.nvim_create_autocmd("User", {
					pattern = "MiniFilesBufferCreate",
					callback = function(args)
						local buf = args.data.buf_id
						vim.keymap.set("n", "yA", function()
							local minifiles = require("mini.files")
							local entry = minifiles.get_fs_entry()
							local MiniVisits = require("mini.visits")
							MiniVisits.add_label(label, entry.path, visit_cwd())
							hi_entry_add(entry, buf, vim.fn.line("."))
						end, { buffer = buf })
						vim.keymap.set("n", "yD", function()
							local minifiles = require("mini.files")
							local entry = minifiles.get_fs_entry()
							local MiniVisits = require("mini.visits")
							MiniVisits.remove_label(label, entry.path, visit_cwd())
							hi_entry_del(entry, buf, vim.fn.line("."))
						end, { buffer = buf })
					end,
				})
				vim.api.nvim_create_autocmd("User", {
					pattern = "MiniFilesBufferUpdate",
					callback = function(args)
						local MiniVisits = require("mini.visits")
						local paths = MiniVisits.list_paths(visit_cwd(), {
							filter = function(path_data)
								return path_data.labels and path_data.labels[label]
							end,
						})
						local buf = args.data.buf_id
						local MiniFiles = require("mini.files")
						local line_count = vim.api.nvim_buf_line_count(buf)
						for line = 1, line_count do
							local entry = MiniFiles.get_fs_entry(buf, line)
							if entry and vim.tbl_contains(paths, entry.path) then
								hi_entry_add(entry, buf, line)
							end
						end
					end,
				})
			end
		end,
		keys = function()
			local label = "core"
			local visit_cwd = function()
				return vim.fn.getcwd(-1, 0)
			end
			local visit_redrawstatusline = function()
				vim.cmd.redrawstatus()
			end
			local has_label_core = function(path_data)
				return path_data.labels and path_data.labels[label]
			end
			local gen_sort = function()
				local MiniVisits = require("mini.visits")
				return MiniVisits.gen_sort.default({ recency_weight = 1 })
			end

			local FzfLuaWithPaths = function(title, path_gen_fn)
				local items = path_gen_fn()
				require("fzf-lua").fzf_exec(items, {
					prompt = title,
					actions = {
						["default"] = function(selected)
							vim.cmd("edit " .. selected[1])
						end,
						["ctrl-x"] = function(selected, opts)
							for _, file in ipairs(selected) do
								local MiniVisits = require("mini.visits")
								print(file)
								MiniVisits.remove_path(file, visit_cwd())
								-- TODO: open picker
							end
						end,
					},
				})
			end
			local SnacksWithPaths = function(title, path_gen_fn)
				Snacks.picker({
					title = title,
					finder = function()
						local paths = path_gen_fn()
						local items = {} ---@type snacks.picker.finder.Item[]
						for i, path in ipairs(paths) do
							local bufnr = vim.fn.bufnr(path, true)
							table.insert(items, {
								buf = bufnr,
								idx = i,
								score = i,
								file = path,
								text = path,
							})
						end
						return items
					end,
					format = "file",
					actions = {
						minivisitdelete = function(picker)
							local MiniVisits = require("mini.visits")

							picker.preview:reset()
							for _, item in ipairs(picker:selected({ fallback = true })) do
								if item.file then
									MiniVisits.remove_path(item.file, visit_cwd())
								end
							end
							picker.list:set_selected()
							picker.list:set_target()
							picker:find()
						end,
					},
					win = {
						input = {
							keys = {
								["<c-x>"] = { "minivisitdelete", mode = { "n", "i" } },
							},
						},
					},
				})
			end

			local maps = {
				{
					"yA",
					function()
						local MiniVisits = require("mini.visits")
						MiniVisits.add_label(label, nil, visit_cwd())
						visit_redrawstatusline()
					end,
				},
				{
					"yD",
					function()
						local MiniVisits = require("mini.visits")
						MiniVisits.remove_label(label, nil, visit_cwd())
						visit_redrawstatusline()
					end,
				},
				{
					"[v",
					function()
						local MiniVisits = require("mini.visits")
						MiniVisits.iterate_paths("backward", visit_cwd(), { wrap = true, filter = has_label_core })
					end,
				},
				{
					"]v",
					function()
						local MiniVisits = require("mini.visits")
						MiniVisits.iterate_paths("forward", visit_cwd(), { wrap = true, filter = has_label_core })
					end,
				},
				{
					"<leader>sv",
					function()
						local MiniVisits = require("mini.visits")
						FzfLuaWithPaths("Mini Visits(" .. label .. ")", function()
							local paths = MiniVisits.list_paths(visit_cwd(), {
								sort = gen_sort(),
								filter = has_label_core,
							})
							return paths
						end)
					end,
				},
				{
					"<leader>so",
					function()
						local cwd = visit_cwd()
						local MiniVisits = require("mini.visits")
						FzfLuaWithPaths(string.format("Mini Visits(%s)", cwd), function()
							local paths = MiniVisits.list_paths(cwd, {
								sort = gen_sort(),
								filter = function(path_data)
									-- skip directory
									return vim.fn.isdirectory(path_data.path) == 0
									-- return path_data.path ~= cwd
								end,
							})
							return paths
						end)
					end,
				},
			}
			return maps
		end,
	},
	{
		"echasnovski/mini.diff",
		event = "VeryLazy",
		init = function()
			_G.Flag_diff_summary = function()
				local summary = vim.b.minidiff_summary_string
				if summary == nil or summary == "" then
					return ""
				end
				local source = vim.b.minidiff_summary.source_name
				return string.format("[%s: %s]", source, summary)
			end
			vim.cmd([[
			autocmd User Flags call Hoist("buffer", 6, "%{v:lua.Flag_diff_summary()}")
			]])
		end,
		opts = {
			view = {
				-- Visualization style. Possible values are 'sign' and 'number'.
				style = "sign",
				-- Signs used for hunks with 'sign' view
				signs = { add = "▒", change = "▒", delete = "▒" },
				-- Priority of used visualization extmarks
				priority = vim.hl.priorities.user - 1,
			},
			-- Source for how reference text is computed/updated/etc
			-- Uses content from Git index by default
			source = nil, -- NOTE(liu): be changed in config function
			-- Delays (in ms) defining asynchronous processes
			delay = {
				-- How much to wait before update following every text change
				text_change = 200,
			},
			-- Module mappings. Use `''` (empty string) to disable one.
			mappings = {
				-- 	-- Apply hunks inside a visual/operator region
				-- 	apply = "gh", -- WRITE TO DIFF SOURCE
				-- 	-- Reset hunks inside a visual/operator region
				-- 	reset = "gH", -- READ FROM DIFF SOURCE
				-- 	-- Hunk range textobject to be used inside operator
				textobject = "ah",
				-- 	-- Go to hunk range in corresponding direction
				-- 	goto_first = "[H",
				-- 	goto_prev = "[h",
				-- 	goto_next = "]h",
				-- 	goto_last = "]H",
			},
			-- Various options
			options = {
				-- Diff algorithm. See `:h vim.diff()`.
				algorithm = "histogram",
				-- Whether to use "indent heuristic". See `:h vim.diff()`.
				indent_heuristic = true,
				-- The amount of second-stage diff to align lines (in Neovim>=0.9)
				linematch = 60,
			},
		},
		config = function(self, opts)
			local MiniDiff = require("mini.diff")

			-- :h MiniDiff-source-specification
			-- Sources in array are attempted to attach in order;
			opts.source = { MiniDiff.gen_source.git(), MiniDiff.gen_source.save() }
			require("mini.diff").setup(opts)

			vim.keymap.set({ "n" }, "[c", function()
				if vim.wo.diff then
					vim.cmd.normal({ "[c", bang = true })
				else
					MiniDiff.goto_hunk("prev")
				end
				vim.cmd.normal("zz")
			end, {
				desc = 'MiniDiff.goto_hunk("prev") or [c',
				noremap = true,
				silent = true,
			})
			vim.keymap.set({ "n" }, "]c", function()
				if vim.wo.diff then
					vim.cmd.normal({ "]c", bang = true })
				else
					MiniDiff.goto_hunk("next")
				end
				vim.cmd.normal("zz")
			end, {
				desc = 'MiniDiff.goto_hunk("next") or ]c',
				noremap = true,
				silent = true,
			})
		end,
	},
	{
		"echasnovski/mini.bufremove",
		lazy = true,
		init = function()
			vim.cmd([[
				function! UserBufDelete() abort
					call v:lua.require("mini.bufremove").delete()
				endfunction
			]])
		end,
	},
	{
		"will133/vim-dirdiff",
	},
	{
		"ibhagwan/fzf-lua",
		init = function()
			local map = function(op, cmd, opts)
				opts = opts or {}
				vim.keymap.set("n", "<leader>s" .. op, function()
					require("fzf-lua")[cmd](opts)
				end)
			end
			map("b", "buffers")
			map("d", "diagnostics_document")
			map("f", "files")
			map("g", "live_grep")
			map("h", "helptags")
			map("m", "marks")
			map("s", "lsp_document_symbols")
			vim.keymap.set("n", "<leader>;", function()
				require("fzf-lua").commands({
					winopts = {
						width = 0.5,
						height = 0.6,
						preview = { hidden = "hidden" },
					},
				})
			end)
		end,
		event = "VeryLazy",
		opts = {
			-- fzf_bin = "sk",
			winopts = {
				backdrop = 80,
				on_create = function()
					local laststatus = vim.o.laststatus
					vim.o.laststatus = 0
					local cur_win = vim.api.nvim_get_current_win()
					vim.api.nvim_create_autocmd("WinClosed", {
						pattern = tostring(cur_win),
						command = "set laststatus=" .. laststatus,
						once = true,
					})
				end,
			},
			fzf_opts = {
				["--cycle"] = true,
				["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-history",
			},
			keymap = {
				builtin = {
					["<C-d>"] = "preview-page-down",
					["<C-u>"] = "preview-page-up",
					["<C-z>"] = "toggle-fullscreen",
				},
				fzf = {
					["ctrl-k"] = "previous-history",
					["ctrl-j"] = "next-history",
					["ctrl-q"] = "select-all+accept",
				},
			},
			actions = {},
		},
	},
	{
		"MagicDuck/grug-far.nvim",
		opts = {
			---@alias liu.grug-far.engine 'ripgrep'|'astgrep'|'astgrep-rules'
			---@type liu.grug-far.engine
			engine = "ripgrep",
		},
		cmd = { "GrugFar", "GrugFarWithin" },
	},
	{
		"stefandtw/quickfix-reflector.vim",
		init = function()
			vim.api.nvim_create_autocmd("VimLeavePre", {
				desc = "delete quickfix-(bufnr) buffers",
				callback = function(args)
					for _, buf in ipairs(vim.api.nvim_list_bufs()) do
						if vim.api.nvim_buf_get_name(buf):match("quickfix-%a") then
							vim.api.nvim_buf_delete(buf, { force = true })
						end
					end
				end,
			})
		end,
		-- event = "VeryLazy",
		ft = "qf",
	},
	{
		"mbbill/undotree",
		-- event = "VeryLazy",
		init = function()
			vim.g.undotree_WindowLayout = 2
			vim.g.undotree_DiffAutoOpen = 1
			vim.g.undotree_ShortIndicators = 1
			vim.g.undotree_SetFocusWhenToggle = 1
			vim.g.undotree_HelpLine = 0

			-- Highlight changed text using signs in the gutter
			vim.g.undotree_HighlightChangedWithSign = 1

			-- vim.g.undotree_DiffCommand = "git diff -p"
			vim.g.undotree_DiffCommand = "diff --unified=2 --minimal --label earlier --label later"

			-- stylua: ignore start
			-- vim.g.undotree_TreeNodeShape = "*"
			vim.g.undotree_TreeReturnShape = "─╮"
			vim.g.undotree_TreeVertShape   =  "│"
			vim.g.undotree_TreeSplitShape  = "─╯"
			-- stylua: ignore end
		end,
		cmd = { "UndotreeToggle" },
	},
	{
		"jpalardy/vim-slime",
		init = function()
			vim.g.slime_target = "neovim" ---@type 'neovim'|'tmux'
			-- vim.g.slime_target = "tmux"
			if vim.env.TMUX then
				-- NOTE: pane name
				-- https://github.com/jpalardy/vim-slime/blob/507107dd24c9b85721fa589462fd5068e0f70266/autoload/slime/targets/tmux.vim#L47
				-- tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{window_name}#{?window_active, (active),}'
				vim.g.slime_target = "tmux" ---@type 'neovim'|'tmux'
			end
			vim.g.slime_no_mappings = true
		end,
		-- ft = { "python" },
		config = function()
			vim.keymap.set("n", "yz", "<Plug>SlimeMotionSend", { remap = true, silent = false })
			vim.keymap.set("n", "yzz", "<Plug>SlimeLineSend", { remap = true, silent = false })
			vim.keymap.set("x", "yz", "<Plug>SlimeRegionSend", { remap = true, silent = false })
			vim.keymap.set("n", "yzc", "<Plug>SlimeConfig", { remap = true, silent = false })
			vim.keymap.set("n", "yz?", ":echo b:slime_config<cr>", { remap = true, silent = false })
		end,
	},
	{
		"tpope/vim-dispatch",
		-- event = "VeryLazy",
		init = function()
			-- m ` ' g' + <cr> <space> ! ?
			--
			-- m  for Make
			-- `  for Dispatch
			-- '  for Start
			-- g' for Spawn
			vim.g.dispatch_no_maps = false

			vim.g.dispatch_compilers = {
				-- python
				["uv run"] = "python",
				["python3"] = "python",
				["python -m pytest"] = "pytest",
				["python3 -m pytest"] = "pytest",
				-- golang
				["golangci-lint run"] = "go",
			}

			local fts = {
				dockerfile = {
					dispatch = "podman build -t %:p:h:t .",
					start = 'podman run --name test_%:p:h:t --rm --security-opt="apparmor=unconfined" --cap-add=SYS_PTRACE %:p:h:t',
				},
			}
			vim.api.nvim_create_autocmd("FileType", {
				desc = "b:dispatch or b:start for FileType",
				pattern = vim.tbl_keys(fts),
				callback = function(args)
					local ft = args.match
					for key, value in pairs(fts[ft]) do
						vim.b[key] = value
					end
				end,
			})
			vim.cmd([[
			autocmd BufReadPost docker-compose.*.y*ml let b:dispatch='docker compose -f % up -d'
			]])

			vim.cmd([[
			autocmd BufReadPost *
			\ if getline(1) =~# '^#!' |
			\   let b:dispatch =
			\       matchstr(getline(1), '#!\%(/usr/bin/env \+\)\=\zs.*') . ' %:S' |
			\   let b:start = '-wait=always ' . b:dispatch |
			\ endif
			]])
		end,
		-- cmd = { "Make", "Dispatch", "Start" },
	},
	{
		"tpope/vim-sleuth",
		-- event = "VeryLazy",
	},
	{
		"tpope/vim-rsi",
		-- event = "VeryLazy",
		init = function(self)
			-- vim.g.rsi_no_meta = 1
		end,
		-- event = { "InsertEnter", "CmdlineEnter" },
	},
	{
		"tpope/vim-eunuch",
		init = function()
			vim.g.eunuch_no_maps = 1
		end,
	},
	{
		"tpope/vim-tbone",
		enabled = false,
		-- event = "VeryLazy",
	},
	{

		"tpope/vim-projectionist",
		-- NOTE:
		-- 1. diff between `alternate` and `related`
		-- A* commands use the `alternate`;
		-- navigation commands created by the `type` will use the `related` is has zero args,
		-- if `related` not exist, use `alternate` as default
		lazy = false,
		-- event = "VeryLazy",
		init = function(self)
			local APPLYTEMPLATE = "APPLYTEMPLATE"
			vim.api.nvim_create_autocmd("User", {
				pattern = "ProjectionistApplyTemplate",
				callback = function(ev)
					local line = vim.fn.getline(1)
					if line == APPLYTEMPLATE then
						vim.cmd.delete() -- delete 1st placeholder line
						if _G.apply_template then
							_G.apply_template(ev.buf)
						end
					end
				end,
			})

			vim.g.projectionist_heuristics = {
				["*"] = {
					["README.md"] = { type = "doc" },
					[".projections.json"] = { type = "projections" },
				},
				-- c {{{
				["*.c&*.h"] = {
					["*.c"] = {
						["alternate"] = "{}.h",
						["type"] = "source",
					},
					["*.h"] = {
						["alternate"] = "{}.c",
						["type"] = "header",
					},
				},
				-- }}}
				-- go {{{
				["go.mod"] = {
					["go.mod"] = { type = "dep" },
					["*.go"] = {
						alternate = "{}_test.go",
						-- related = "{}_test.go",
						type = "source",
						template = [[package {file|dirname|basename}]],
						dispatch = "go run %",
					},
					["*_test.go"] = {
						alternate = "{}.go",
						-- related = "{}.go",
						type = "test",
						template = [[package {file|dirname|basename}_test]],
						dispatch = "go test ./...",
					},
					["cmd/*/main.go"] = {
						type = "main", -- argument will replace the glob
						template = "package main",
						dispatch = "go run {file|dirname}",
						start = "go run {file|dirname}",
						make = "go build {file|dirname}",
					},
					["main.go"] = {
						-- If this option is provided for a literal filename rather than a glob,
						-- it is used as the default destination of the navigation command when no argument is given.
						type = "main",
						template = "package main",
						dispatch = "go run {file|dirname}",
						start = "go run {file|dirname}",
						make = "go build {file|dirname}",
					},
					["*.proto"] = {
						dispatch = "protoc "
							.. "--go_out={file|dirname} --go_opt=paths=source_relative "
							.. "--go-grpc_out={file|dirname} --go-grpc_opt=paths=source_relative "
							.. "--proto_path={file|dirname} "
							.. "{file}",
						type = "proto",
						template = vim.iter({
							[[syntax = "proto3";]],
							[[package {basename};]],
							[[option go_package="{basename}";]],
						}):join("\n"),
					},
				},
				-- }}}
				-- python {{{
				["pyproject.toml|.venv/"] = {
					["pyproject.toml"] = {
						type = "dep",
					},
					["*.py"] = {
						type = "source",
						alternate = {
							-- Test file in `tests` subdir
							"tests/test_{basename}.py",
							"tests/{dirname}/test_{basename}.py",
							-- Test file in parallel `test` dir, e.g.
							-- Source: <proj_name>/<mod>/<submod>/*.py
							-- Tests:  tests/<mod>/<submod>/test_*.py
							"tests/{dirname|tail}/test_{basename}.py",
							-- Test file for module, e.g.
							-- Source: <mod>/<submod>/*.py
							-- Tests:  <mod>/test_<submod>.py
							--         tests/<mod>/test_<submod>.py
							"tests/{dirname|dirname}/test_{dirname|basename}.py",
							"tests/{dirname|tail|dirname}/test_{dirname|basename}.py",
						},
						dispatch = "python %",
					},
					["tests/**/test_*.py"] = {
						type = "test",
						alternate = {
							"{}.py", -- source file in parent dir
							"{}/__init__.py", -- module test
							-- Source file in parallel `src` dir
							"src/{}.py",
							"src/{}/__init__.py",
							-- Guess source file containing dir (project dir)
							-- using base of project fullpath, not always correct.
							-- Required struct:
							-- Source: [PROJECT]/<proj_name>/<mod>/<submod>/*.py
							-- Tests:  [PROJECT]/tests/<mod>/<submod>/test_*.py
							-- where [PROJECT] ends with <proj_name>
							"{project|basename}/{}.py",
							"{project|basename}/{}/__init__.py",
						},
						dispatch = "python -m pytest -s %",
					},
				},
				-- }}}
				-- zig {{{
				["build.zig"] = {
					["build.zig"] = {
						type = "build",
						alternate = "build.zig.zon",
					},
					["build.zig.zon"] = {
						type = "dep",
						alternate = "build.zig",
					},
					["*"] = {
						start = "zig build run",
						dispatch = "zig test",
					},
					["src/main.zig"] = {
						type = "main",
						template = [[pub fn main() !void {|open}{|close}]],
					},
				},
				-- }}}
				-- rust {{{
				["Cargo.toml"] = {
					["Cargo.toml"] = { type = "dep" },
					["build.rs"] = { type = "build" },
					["src/*.rs"] = {
						type = "source",
						alternate = "tests/{}.rs",
					},
					["tests/*.rs"] = {
						type = "test",
						alternate = "src/{}.rs",
						dispatch = "cargo test {}",
					},
					["benchmarks/*.rs"] = { type = "bench" },
				},
				-- }}}
			}

			-- Extra transformers
			-- https://github.com/tpope/vim-projectionist/blob/5ff7bf79a6ef741036d2038a226bcb5f8b1cd296/autoload/projectionist.vim#L255
			if not vim.g.projectionist_transformations then
				vim.g.projectionist_transformations = vim.empty_dict()
			end
			vim.cmd([[
			"https://github.com/Bekaboo/dot/blob/8e5357d51f7c5b07a329e2ef8a5c6befd268690e/.config/nvim/lua/configs/vim-projectionist.lua#L10
			" Remove first slash separated component
			function! g:projectionist_transformations.tail(input, o) abort
				return substitute(a:input, '\(\/\)*[^/]\+\/*', '\1', '')
			endfunction
			]])

			-- autocmds {{{
			-- autocmd("User", {
			-- 	pattern = "ProjectionistDetect",
			-- 	callback = function(ev)
			-- 		vim.notify("[Projections] detect!", vim.log.levels.INFO)
			-- 		vim.print(vim.g.projectionist_file)
			-- 	end,
			-- })
			--
			-- autocmd("User", {
			-- 	pattern = "ProjectionistActivate",
			-- 	callback = function(ev)
			-- 		-- property can be defined
			-- 		-- [root, property_value]
			-- 		vim.fn["projectionist#query"]("property")
			-- 	end,
			-- })
			-- }}}
		end,
		keys = {
			{ "<leader>aa", "<cmd>A<cr>" },
			{ "<leader>as", "<cmd>AS<cr>" },
			{ "<leader>av", "<cmd>AV<cr>" },
		},
	},
	{
		"tpope/vim-obsession",
		-- event = "VeryLazy",
		init = function()
			vim.cmd([[
			setglobal sessionoptions-=buffers 
			setglobal sessionoptions+=globals
			"setglobal sessionoptions-=curdir 
			"setglobal sessionoptions+=sesdir

			autocmd VimEnter * nested
					\ if !argc() && empty(bufname()) && empty(v:this_session) && filereadable('Session.vim') && !&modified |
					\   source Session.vim |
					\ endif
			]])
		end,
	},
}
