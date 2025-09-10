-- NOTE: build in feature enhance
-- 1. file navigation
-- 2. bufwipe, keymap, diff
-- 3. find-replace
-- fzf
-- undotree
-- compiler
-- session
-- readline mappings for insert and command line
-- UNIX shell commands
-- globs & file
-- ...
local user_border = require("liu.user_config").borders

return {
	{
		"justinmk/vim-dirvish",
		enabled = true,
		init = function(self)
			vim.g.loaded_netrwPlugin = 1

			vim.cmd([[
				command! -nargs=? -complete=dir Explore Dirvish <args>
			    command! -nargs=? -complete=dir Sexplore belowright split | silent Dirvish <args>
			    command! -nargs=? -complete=dir Vexplore leftabove vsplit | silent Dirvish <args>
			]])

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
	},
	{
		"echasnovski/mini.files",
		lazy = true,
		init = function()
			local aug = vim.api.nvim_create_augroup("liu/mini.files", { clear = true })
			vim.api.nvim_create_autocmd("User", {
				pattern = "MiniFilesBufferCreate",
				group = aug,
				callback = function(args)
					local buf = args.data.buf_id

					vim.b[buf].completion = false -- disable blink.cmp
					-- vim.b[buf].minivisits_disable = true

					local MiniFiles = require("mini.files")
					do
						-- https://github.com/echasnovski/mini.nvim/issues/391
						-- set up ability to confirm changes with :w
						-- api.nvim_create_autocmd("BufWriteCmd", {
						-- 	callback = MiniFiles.synchronize,
						-- 	buffer = buf,
						-- })
						vim.api.nvim_set_option_value("buftype", "nowrite", { buf = buf })
					end

					vim.keymap.set("n", "gx", function()
						vim.ui.open(MiniFiles.get_fs_entry().path)
					end, { buffer = buf, desc = "OS open" })

					vim.keymap.set("n", "<CR>", function()
						MiniFiles.go_in({ close_on_file = true })
					end, { buffer = buf })
					vim.keymap.set("n", "<leader><CR>", MiniFiles.synchronize, { buffer = buf })

					vim.keymap.set("n", "g.", function()
						local path = MiniFiles.get_fs_entry().path
						MiniFiles.close()
						vim.fn.feedkeys(": " .. path)
						vim.fn.feedkeys(vim.keycode("<HOME>"))
					end, { buffer = buf })

					local get_win_path = function()
						local state = MiniFiles.get_explorer_state()
						local window = vim.iter(state.windows):find(function(win)
							return win.win_id == vim.api.nvim_get_current_win()
						end)
						return window and window.path or vim.fn.getcwd()
					end
					vim.keymap.set("n", "cd", function()
						local path = get_win_path()
						MiniFiles.close()
						vim.cmd.lcd(path)
					end, { buffer = buf })
					vim.keymap.set("n", "cD", function()
						local path = get_win_path()
						MiniFiles.close()
						vim.cmd([[bo new]])
						vim.fn.jobstart(vim.o.shell, { term = true, cwd = path })
					end, { buffer = buf })

					vim.keymap.set("n", "y<leader>", function()
						local path = MiniFiles.get_fs_entry().path
						local p
						if vim.v.count > 0 then
							p = vim.fn.fnamemodify(path, ":p")
						else
							p = vim.fn.fnamemodify(path, ":.")
						end
						vim.fn.setreg(vim.v.register, p)
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

			vim.api.nvim_create_autocmd("User", {
				group = aug,
				pattern = "MiniFilesExplorerOpen",
				callback = function()
					local MiniFiles = require("mini.files")
					MiniFiles.set_bookmark("~", "~", { desc = "Home directory" })
					MiniFiles.set_bookmark("w", vim.fn.getcwd, { desc = "Working directory" })
					MiniFiles.set_bookmark("r", function()
						return vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
					end, { desc = "Root directory" })
				end,
			})
		end,
		keys = {
			{
				"<leader>e",
				function()
					local MiniFiles = require("mini.files")
					if not MiniFiles.close() then
						local bufname = vim.api.nvim_buf_get_name(0)
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
				local hi_entry_remove = function(entry, buf, line)
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
						local MiniVisits = require("mini.files")
						vim.keymap.set("n", "yA", function()
							local entry = MiniVisits.get_fs_entry()
							MiniVisits.add_label(label, entry.path, visit_cwd())
							hi_entry_add(entry, buf, vim.fn.line("."))
						end, { buffer = buf })
						vim.keymap.set("n", "yD", function()
							local entry = MiniVisits.get_fs_entry()
							MiniVisits.remove_label(label, entry.path, visit_cwd())
							hi_entry_remove(entry, buf, vim.fn.line("."))
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

			-- vim-flagship {{{
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
			-- }}}
		end,
		keys = function()
			local label = "core"
			local visit_cwd = function()
				return vim.fn.getcwd(-1, 0)
			end
			local has_label_core = function(path_data)
				return path_data.labels and path_data.labels[label]
			end
			local gen_sort = function()
				local MiniVisits = require("mini.visits")
				return MiniVisits.gen_sort.default({ recency_weight = 1 })
			end

			local FzfLuaWithPaths = function(title, path_gen_fn)
				local make_entry = require("fzf-lua.make_entry")
				local make_opts = {
					_type = "file",
					strip_cwd_prefix = true,
					path_shorten = false,
					cwd = visit_cwd(),
				}
				local contents = function(cb)
					local items = path_gen_fn()
					for _, item in ipairs(items) do
						cb(make_entry.file(item, make_opts))
					end
					cb(nil)
				end

				local remove_path = function(selected)
					for _, file in ipairs(selected) do
						local MiniVisits = require("mini.visits")
						MiniVisits.remove_path(file, visit_cwd())
					end
				end

				local opts = {
					prompt = title,
					cwd = visit_cwd(),
					previewer = "builtin",
					fzf_opts = { ["--tiebreak"] = "index", ["--multi"] = true },
					actions = {
						default = require("fzf-lua.actions").file_edit,
						["ctrl-x"] = { fn = remove_path, reload = true },
					},
				}
				require("fzf-lua").fzf_exec(contents, opts)
			end

			local maps = {
				{
					"m<tab>",
					function()
						local MiniVisits = require("mini.visits")
						local labels = MiniVisits.list_labels(vim.fn.bufname(), visit_cwd())
						local op = MiniVisits.add_label
						if vim.tbl_contains(labels, label) then
							op = MiniVisits.remove_label
						end
						op(label, nil, visit_cwd())
						vim.cmd.redrawstatus()
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
						FzfLuaWithPaths(string.format("Mini Visits(%s)", vim.fn.pathshorten(cwd, 2)), function()
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
		"echasnovski/mini.bufremove",
		lazy = true,
		init = function()
			vim.cmd([[
				function! UserBufDelete() abort
					call v:lua.require("mini.bufremove").delete()
				endfunction
			]])

			vim.api.nvim_create_autocmd("User", {
				pattern = "MiniFilesActionDelete",
				group = g,
				callback = function(args)
					local fname = args.data.from
					local bufnr = vim.fn.bufnr(fname)
					if bufnr > 0 then
						-- delte buffer
						require("mini.bufremove").delete(bufnr, false)
					end
				end,
			})
		end,
	},
	{
		"echasnovski/mini.keymap",
		-- event = "VeryLazy",
		init = function()
			local map_combo = require("mini.keymap").map_combo
			local mode = { "i", "x", "s" }
			map_combo(mode, "jk", "<BS><BS><Esc>")

			local map_multistep = require("mini.keymap").map_multistep
			map_multistep({ "i", "s" }, "<Tab>", {
				"vimsnippet_next",
				"blink_next",
				"pmenu_next",
			})
			map_multistep({ "i", "s" }, "<S-Tab>", {
				"vimsnippet_prev",
				"blink_prev",
				"pmenu_prev",
			})
			-- snippet mappings
			map_multistep({ "i", "s" }, "<C-l>", {
				"vimsnippet_next",
			})
			map_multistep({ "i", "s" }, "<C-h>", {
				"vimsnippet_prev",
			})
		end,
		opts = {},
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
		"deathbeam/difftool.nvim",
		-- "will133/vim-dirdiff",
	},
	{
		"MagicDuck/grug-far.nvim",
		opts = {
			---@alias liu.grug-far.engine 'ripgrep'|'astgrep'|'astgrep-rules'
			---@type liu.grug-far.engine
			engine = "ripgrep",
			-- https://github.com/MagicDuck/grug-far.nvim/blob/385d1949dc21d0c39e7a74b4f4a25da18817bc86/doc/grug-far-opts.txt#L301
			keymaps = {
				historyOpen = { n = "<localleader>ho" },
				historyAdd = { n = "<localleader>ha" },

				refresh = { n = "<localleader>R" },
				abort = { n = "<localleader>Q" },

				toggleShowCommand = { n = "gd" },

				qflist = { n = "<localleader>q" },

				-- location
				previewLocation = { n = "<localleader>p" },
				openLocation = { n = "<localleader>o" },
				openNextLocation = { n = "<c-n>" },
				openPrevLocation = { n = "<c-p>" },
				-- sync
				syncLocations = { n = "<localleader>sa" }, -- sync all
				syncFile = { n = "<localleader>sf" },
				syncLine = { n = "<localleader>sl" },
				syncNext = { n = "<localleader>sn" },
				syncPrev = { n = "<localleader>sp" },
			},
		},
		cmd = { "GrugFar", "GrugFarWithin" },
	},
	{
		"ibhagwan/fzf-lua",
		init = function()
			vim.ui.select = function(...)
				require("fzf-lua.providers.ui_select").ui_select(...)
			end

			local map = function(op, cmd, opts)
				opts = opts or {}
				vim.keymap.set("n", "<leader>s" .. op, function()
					require("fzf-lua")[cmd](opts)
				end)
			end
			map("a", "args")
			map("b", "buffers")
			map("d", "diagnostics_document")
			map("f", "files")
			map("g", "live_grep")
			map("h", "helptags")
			map("m", "marks")
			map("s", "lsp_document_symbols")
			map("w", "grep_cword")
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
				border = user_border,
				preview = {
					border = user_border,
				},
				-- winopts = {},
				on_create = function()
					local laststatus = vim.o.laststatus
					vim.o.laststatus = 0
					vim.o.showmode = not vim.o.showmode
					local cur_win = vim.api.nvim_get_current_win()
					vim.api.nvim_create_autocmd("WinClosed", {
						pattern = tostring(cur_win),
						command = vim.iter({
							"set laststatus=" .. laststatus,
							"set showmode!",
						}):join("|"),
						once = true,
					})
				end,
				-- on_close = function() end,
			},
			keymap = {
				builtin = {
					false, -- do not inherit from the defaults
					["<C-d>"] = "preview-page-down",
					["<C-u>"] = "preview-page-up",
					["<C-z>"] = "toggle-fullscreen",
				},
				fzf = {
					false, -- do not inherit from the defaults
					["ctrl-a"] = "beginning-of-line",
					["ctrl-e"] = "end-of-line",
					["ctrl-k"] = "previous-history",
					["ctrl-j"] = "next-history",
					["ctrl-q"] = "select-all+accept",
				},
			},
			actions = {},
			fzf_opts = {
				["--cycle"] = true,
				["--history"] = vim.fn.stdpath("data") .. "/fzf-lua-history",
			},
			hls = {
				preview_border = "WinSeparator",
				border = "WinSeparator",
			},
			previewers = {},
			lsp = {
				symbols = {
					symbol_style = 3,
				},
			},
		},
	},
	{
		"folke/flash.nvim",
		opts = {
			modes = {
				search = {
					enabled = false,
				},
				char = {
					enabled = false,
				},
			},
			prompt = {
				enabled = false,
			},
		},
		keys = {
			-- stylua: ignore start
			{ "s", mode = { "n", "x" }, function() require("flash").jump() end, desc = "Flash" },
			{ "s<cr>", mode = { "n" }, function() require("flash").jump({ continue = true }) end, desc = "Flash" },
			{ "z", mode = { "o" }, function() require("flash").jump() end, desc = "Flash" },
			{ "Z", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
			-- stylua: ignore end
		},
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
		keys = { { "yuu", "<cmd>UndotreeToggle<cr>" } },
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
			autocmd BufReadPost *
			\ if getline(1) =~# '^#!' |
			\   let b:dispatch =
			\       matchstr(getline(1), '#!\%(/usr/bin/env \+\)\=\zs.*') . ' %:S' |
			\   let b:start = '-wait=always ' . b:dispatch |
			\ endif


			autocmd BufReadPost docker-compose.*.y*ml
			\ if getline(1) =~# '^#!' |
			\   let b:dispatch = 'docker compose -f % up -d' |
			\   let b:start = '-wait=always ' . b:dispatch |
			\ endif

			autocmd FileType python
			\ if getline(1) =~# '^# /// script' |
			\   let b:dispatch = 'uv run --script %' |
			\   let b:start = '-wait=always ' . b:dispatch |
			\ endif
			]])
		end,
		-- cmd = { "Make", "Dispatch", "Start" },
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
				  \ if !argc() && empty(bufname()) && empty(v:this_session) && !&modified |
				  \   if filereadable('Session.vim') |
				  \     source Session.vim |
				  \   elseif filereadable('.git/Session.vim') |
				  \     source .git/Session.vim |
				  \   endif |
				  \ endif
			]])
		end,
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
				["package.json"] = {
					["*.ts"] = {
						alternate = "{}.test.ts",
						type = "source",
						dispatch = "bun run --hot %",
					},
					["*.test.ts"] = {
						alternate = "{}.ts",
						type = "test",
						dispatch = "bun test %",
					},
				},
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
}
