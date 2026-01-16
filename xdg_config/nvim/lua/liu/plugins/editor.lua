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

local utils = require("liu.utils")

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
					-- Use <C-w>s and <C-w>v to match vim's built-in window split commands
					-- dirvish commands:
					--   o: open in horizontal split
					--   a: open in vertical split
					--   O/A: operate on selected files in visual mode
					-- Use noremap=false (remap=true) to allow dirvish's internal mappings to work
					-- But add silent to prevent triggering other behaviors
					-- Buffer-local mappings should override built-in commands
					vim.keymap.set("n", "<C-w>s", "o", { remap = true, buffer = ev.buf, desc = "Split horizontally", silent = true, nowait = true })
					vim.keymap.set("n", "<C-w>v", "a", { remap = true, buffer = ev.buf, desc = "Split vertically", silent = true, nowait = true })
					vim.keymap.set("v", "<C-w>s", "O", { remap = true, buffer = ev.buf, desc = "Split selected horizontally", silent = true, nowait = true })
					vim.keymap.set("v", "<C-w>v", "A", { remap = true, buffer = ev.buf, desc = "Split selected vertically", silent = true, nowait = true })
				end,
			})
		end,
	},
	{
		"nvim-mini/mini.files",
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
						-- https://github.com/nvim-mini/mini.nvim/issues/391
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
					end, { buffer = buf, desc = "Go in (close on file)" })
					vim.keymap.set("n", "<leader><CR>", MiniFiles.synchronize, { buffer = buf, desc = "Synchronize changes" })

					vim.keymap.set("n", "g.", function()
						local path = MiniFiles.get_fs_entry().path
						MiniFiles.close()
						vim.fn.feedkeys(": " .. path)
						vim.fn.feedkeys(vim.keycode("<HOME>"))
					end, { buffer = buf, desc = "Put path in command line" })

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
					end, { buffer = buf, desc = "Change directory to current path" })
					vim.keymap.set("n", "cD", function()
						local path = get_win_path()
						MiniFiles.close()
						vim.cmd([[bo new]])
						vim.fn.jobstart(vim.o.shell, { term = true, cwd = path })
					end, { buffer = buf, desc = "Open terminal in current path" })

					-- Helper function to yank path (relative by default, full path with count)
					local yank_path = function(path, ensure_dir)
						-- Ensure directory path if needed
						if ensure_dir then
							if vim.fn.isdirectory(path) == 0 then
								path = vim.fn.fnamemodify(path, ":h")
							end
							-- Ensure trailing slash
							if path:sub(-1) ~= "/" then
								path = path .. "/"
							end
						end
						local full_path = vim.fn.fnamemodify(path, ":p")
						local cwd = vim.fn.getcwd()
						-- Make relative to cwd (same as global y<leader> behavior)
						local rel_path = vim.fn.substitute(full_path, "^" .. vim.fn.escape(cwd, "\\") .. "/", "", "")
						-- If count > 0, use full path; otherwise use relative path
						local p = vim.v.count > 0 and full_path or rel_path
						vim.fn.setreg("+", p)
						vim.fn.setreg("*", p)
						vim.cmd('echo "copy: " . @+')
					end

					-- Unified with global y<leader> mapping for consistency
					-- Same behavior: relative path by default, full path with count
					vim.keymap.set("n", "y<leader>", function()
						local path = MiniFiles.get_fs_entry().path
						yank_path(path, false)
					end, { buffer = buf, desc = "Yank path" })

					-- Yank directory path (current window's directory)
					-- Same behavior: relative path by default, full path with count
					vim.keymap.set("n", "yd", function()
						local dir_path = get_win_path()
						yank_path(dir_path, true)
					end, { buffer = buf, desc = "Yank directory path" })

					local map_split = function(buf_id, lhs, direction)
						-- First, try to delete any existing mapping to ensure clean override
						pcall(vim.keymap.del, "n", lhs, { buffer = buf_id })
						
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
						-- Use noremap, silent, and nowait to prevent recursion and ensure it overrides built-in commands
						vim.keymap.set("n", lhs, rhs, { buffer = buf_id, desc = desc, noremap = true, silent = true, nowait = true })
					end
					-- Use <C-w>s and <C-w>v to match vim's built-in window split commands
					map_split(buf, "<C-w>s", "belowright horizontal")
					map_split(buf, "<C-w>v", "belowright vertical")

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
					MiniFiles.set_bookmark("C", vim.fn.stdpath("config"), { desc = "nvim Config directory" })
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
				-- Use single-key mappings following vim conventions, no Ctrl needed
				go_in = "<c-l>",        -- Enter directory or open file (default)
				go_out = "<c-h>",       -- Go to parent directory (default)
				go_in_plus = "",   -- Enter and close file explorer
				go_out_plus = "",  -- Go out and trim right columns

				mark_set = "m",
				mark_goto = "`",
			},
			options = { use_as_default_explorer = false },
		},
	},
	{
		"nvim-mini/mini.bufremove",
		lazy = true,
		init = function()
			vim.cmd([[
				function! UserBufDelete() abort
					call v:lua.require("mini.bufremove").delete()
				endfunction
			]])

			vim.api.nvim_create_autocmd("User", {
				pattern = "MiniFilesActionDelete",
				callback = function(args)
					local fname = args.data.from
					local bufnr = vim.fn.bufnr(fname)
					if bufnr > 0 then
						-- delete buffer
						require("mini.bufremove").delete(bufnr, false)
					end
				end,
			})
		end,
	},
	{
		"nvim-mini/mini.keymap",
		-- event = "VeryLazy",
		init = function()
			local map_combo = require("mini.keymap").map_combo
			local mode = { "i", "x", "s" }
			map_combo(mode, "jk", "<BS><BS><Esc>")

			local inline_completion = {
				condition = function()
					return true
				end,
				action = function()
					return vim.lsp.inline_completion.get()
				end,
			}

			local map_multistep = require("mini.keymap").map_multistep
			map_multistep({ "i" }, "<Tab>", {
				"vimsnippet_next",
				"pmenu_next",
				-- "blink_next",
				inline_completion,
			})
			map_multistep({ "i" }, "<S-Tab>", {
				"vimsnippet_prev",
				"pmenu_prev",
				-- "blink_prev",
			})
			-- map_multistep({ "s" }, "<Tab>", {
			-- 	"vimsnippet_next",
			-- 	"pmenu_next",
			-- 	"blink_next",
			-- })
			-- map_multistep({ "s" }, "<S-Tab>", {
			-- 	"vimsnippet_prev",
			-- 	"pmenu_prev",
			-- 	"blink_prev",
			-- })
			--
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
		"nvim-mini/mini.diff",
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
		"serhez/bento.nvim",
		enabled = false,
		event = "VeryLazy",
		opts = {
			main_keymap = "\\",
			lock_char = "*",
			ui = {
				mode = "floating", -- "floating" | "tabline"
				floating = {
					position = "top-right", -- "top-left" | "top-right" | "middle-left" | "middle-right" | "bottom-left" | "bottom-right"
					minimal_menu = "dashed", -- "filename" | "dashed" | "full"
				},
			},
		},
	},
	{
		"MagicDuck/grug-far.nvim",
		enabled = false,
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
		"gh-liu/nvim-winterm",
		dev = true,
		opts = {},
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
				["go test"] = "gotest",
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
			nmap `<bs> <cmd>AbortDispatch<cr>

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
					["src/main.rs"] = {
						type = "main",
					},
					["src/*.rs"] = {
						type = "source",
						alternate = "tests/{}.rs",
						dispatch = "cargo run {}",
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
			-- vim.api.nvim_create_autocmd("User", {
			-- 	pattern = "ProjectionistDetect",
			-- 	callback = function(ev)
			-- 		vim.print("searching for projections.")
			-- 		vim.print(vim.g.projectionist_file)
			-- 		-- vim.notify("[Projections] detect! " .. vim.g.projectionist_file, vim.log.levels.INFO)
			-- 	end,
			-- })
			--
			-- vim.api.nvim_create_autocmd("User", {
			-- 	pattern = "ProjectionistActivate",
			-- 	callback = function(ev)
			-- 		vim.print("projections are found.")
			-- 		-- property can be defined
			-- 		-- [root, property_value]
			-- 		local data = vim.fn["projectionist#query"]("type")
			-- 		vim.print(data)
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
