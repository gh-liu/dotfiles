-- local config = require("liu.user_config")
local api = vim.api
-- local fn = vim.fn

---@param cmds table
local set_cmds = function(cmds, opts)
	for key, cmd in pairs(cmds) do
		vim.api.nvim_create_user_command(key, cmd, opts or { bang = true, nargs = 0 })
	end
end

---@param highlights table
local set_hls = function(highlights)
	for group, opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, group, opts)
	end
end
return { -- Git {{{2
	{
		"tpope/vim-fugitive",
		-- event = "VeryLazy",
		dependencies = {
			"tpope/vim-rhubarb",
			-- { "shumphrey/fugitive-gitlab.vim" },
		},
		config = function()
			-- https://github.com/tpope/vim-fugitive/issues/1080#issuecomment-521100430
			vim.g.oremap = {
				["[m"] = "[f",
				["]m"] = "]f",
			}
			vim.g.xremap = {
				["[m"] = "[f",
				["]m"] = "]f",
			}
			vim.g.nremap = {
				["="] = "<TAB>",
				["[m"] = "[f",
				["]m"] = "]f",
			}

			-- vim.keymap.set("n", "\\g", ":Git ")
			vim.keymap.set("n", "<leader>ge", "<cmd>Gedit<cr>")
			vim.keymap.set("n", "<leader>gw", "<cmd> try | Gwrite | catch /.*/ | update | endtry <cr>")
			local g = vim.api.nvim_create_augroup("liu/fugitive/setup", { clear = true })
			vim.api.nvim_create_autocmd("FileType", {
				group = g,
				pattern = "fugitive",
				callback = function(args)
					vim.cmd([[
					nnoremap <buffer> rt :<C-U>Git reset @~<C-R>=v:count1<CR><CR>
					]])
				end,
			})
			api.nvim_create_autocmd("User", {
				group = g,
				pattern = { "FugitiveObject", "FugitiveIndex" },
				callback = function(data)
					local buf = data.buf
					vim.keymap.set("n", "q", "<cmd>bd<cr>", { buffer = buf })
				end,
			})

			--- Toggle summary window {{{3
			local G = {
				buf = -1,
				toggle = function(self)
					if self.buf > 0 then
						api.nvim_buf_call(self.buf, function()
							vim.cmd.bw()
							self.buf = -1
						end)
					else
						vim.cmd.G({ mods = { keepalt = true, keepjumps = true } })
					end
				end,
			}

			vim.keymap.set("n", "g<space>", function()
				G:toggle()
			end, { silent = true })

			api.nvim_create_autocmd("User", {
				group = g,
				pattern = { "FugitiveIndex" },
				callback = function(data)
					vim.bo.bufhidden = "wipe"

					G.buf = data.buf
					api.nvim_create_autocmd("BufDelete", {
						callback = function()
							G.buf = -1
						end,
						buffer = data.buf,
					})
				end,
			})

			-- }}}

			--- Absorb {{{
			api.nvim_create_autocmd("User", {
				group = g,
				pattern = { "FugitiveIndex" },
				callback = function(data)
					-- git absorb
					-- @need-install: cargo install git-absorb
					vim.keymap.set("n", "gaa", ":Git absorb<space>", { buffer = 0 })
					vim.keymap.set("n", "gar", ":Git absorb --and-rebase<space>", { buffer = 0 })
				end,
			})
			-- }}}

			--- Stash {{{3
			local stash_list_cmd = "--paginate stash list '--pretty=format:%h %as %<(10)%gd %<(76,trunc)%s'"

			api.nvim_create_autocmd("User", {
				group = g,
				pattern = { "FugitiveIndex" },
				callback = function(data)
					vim.keymap.set("n", "czl", ":G " .. stash_list_cmd .. "<CR>", { buffer = 0 })
				end,
			})

			api.nvim_create_autocmd("User", {
				group = g,
				pattern = { "FugitivePager" },
				callback = function(data)
					local buf = data.buf

					vim.bo.bufhidden = "delete"

					local refresh_stash_list = function()
						vim.api.nvim_buf_call(buf, function()
							vim.cmd(":0G " .. stash_list_cmd)
						end)
					end
					local get_stash = function()
						local line = vim.api.nvim_get_current_line()

						local _, _, hash, stash_idx = line:find([[(%x+).*(stash@{%d})]])
						return stash_idx
					end
					local op_stash = function(fn)
						local hash = get_stash()
						if hash then
							fn(hash)
							refresh_stash_list()
						end
					end

					local stash_ops = {
						czd = function(idx)
							vim.cmd("Git stash drop --quiet " .. idx)
						end,
						czO = function(idx)
							vim.cmd("Git stash pop --quiet " .. idx)
						end,
						czo = function(idx)
							vim.cmd("Git stash pop --quiet --index " .. idx)
						end,
					}
					for lhs, op in pairs(stash_ops) do
						vim.keymap.set("n", lhs, function()
							op_stash(op)
						end, { buffer = buf })
					end
				end,
			})

			api.nvim_create_autocmd("User", {
				group = g,
				pattern = { "FugitiveIndex" },
				callback = function(data)
					vim.keymap.set("n", "czm", ":G stash save<space>", { buffer = 0, nowait = true })
					-- vim.keymap.set("n", "czmw", ":G stash save -k<space>", { buffer = 0 })
					-- vim.keymap.set("n", "czms", ":G stash save -S<space>", { buffer = 0 })
				end,
			})
			--- }}}

			api.nvim_create_autocmd("BufReadPost", {
				group = g,
				pattern = { "fugitive://*", ".git/*" },
				callback = function(data)
					vim.b[data.buf].minivisits_disable = true
				end,
			})

			api.nvim_create_autocmd("FileType", {
				desc = "fold method for git buffer",
				pattern = { "git", "fugitive" },
				callback = function(args)
					vim.wo[0][0].foldmethod = "syntax"
				end,
			})

			api.nvim_create_autocmd("User", {
				group = g,
				pattern = { "FugitiveCommit" },
				callback = function(ev)
					vim.api.nvim_buf_create_user_command(
						ev.buf,
						"Gfiles",
						":let commit=fugitive#Object(@%) | exec 'G<bang> difftool --name-only ' .. commit .. '~' .. ' '.. commit",
						{ bang = true }
					)
				end,
			})

			set_cmds({
				Gfiles = "G<bang> difftool --name-only",
				-- 3 way diff
				-- https://dzx.fr/blog/introduction-to-vim-fugitive/#3-way-diff
				Gconflict = "tabnew % | Gvdiffsplit! | Gvdiffsplit! :1 | wincmd J",
			})

			-- NOTE: review workflow
			-- 0. review between @ and FETCH_HEAD or 1st args
			-- 1. checkout remote branch
			-- 2. checkout back to master branch
			set_cmds({
				-- 3. GRcommit to show commits
				-- 3.1 there is a `Gfiles` command to show files of current commit
				GRcommit = 'let g:diff_target = get(g:, "diff_target", len(<q-args>)==0?"FETCH_HEAD":<q-args>)'
					.. '| exec "Gclog<bang> @.." .. g:diff_target',
				-- 4. GRfiles to show files
				GRfiles = 'let g:diff_target = get(g:, "diff_target", len(<q-args>)==0?"FETCH_HEAD":<q-args>)'
					.. '| let g:diff_base = trim(execute("G merge-base @ " .. g:diff_target))'
					.. '| exec "G<bang> difftool --name-only " .. g:diff_base ..  " " .. g:diff_target',
			}, {
				bang = true,
				nargs = "?",
				complete = function()
					local dir = vim.fn["FugitiveGitDir"]()
					local merge_heads = { "MERGE_HEAD", "REBASE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD" }
					local heads = vim.tbl_deep_extend("keep", { "HEAD", "FETCH_HEAD", "ORIG_HEAD" }, merge_heads)
					heads = vim.iter(heads)
						:filter(function(h)
							local path = vim.fs.joinpath(dir, h)
							return vim.fn.filereadable(path) == 1
						end)
						:totable()
					local r = vim.fn["fugitive#Execute"](dir, "rev-parse", "--symbolic", "--branches")
					local result = {}
					if r.exit_status == 0 then
						result = vim.iter(r.stdout)
							:filter(function(item)
								return #item > 0
							end)
							:totable()
					end
					for _, val in ipairs(result) do
						table.insert(heads, val)
					end
					return vim.fn.sort(heads)
				end,
			})

			set_hls({
				diffAdded = { link = "DiffAdd" },
				diffRemoved = { link = "DiffDelete" },
			})
		end,
	},
	{
		"rbong/vim-flog",
		init = function(self)
			vim.g.flog_use_internal_lua = 1
			vim.g.flog_default_opts = { max_count = 2000 }
			vim.g.flog_permanent_default_opts = { date = "format:%Y-%m-%d %H:%m" }

			-- keymap.set("ca", "F", "Flog", {})
			vim.keymap.set("ca", "F", "Flogsplit", {})

			api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("liu/flog/setup", { clear = true }),
				pattern = "floggraph",
				callback = function(ev)
					local buf = ev.buf
					local nmap = function(lhs, rhs, opts)
						opts = opts or { buffer = buf, silent = true }
						vim.keymap.set("n", lhs, rhs, opts)
					end

					nmap("o", "<Plug>(FlogVSplitCommitRight)")
					nmap("q", "<Plug>(FlogQuit)")

					-- :h flog-%h
					-- The hash of the commit under the cursor, if any.

					-- git reset --mixed/hard
					nmap("cRm", "<Cmd>exec flog#Format('Floggit reset %h')<CR>")
					nmap("cRh", "<Cmd>exec flog#Format('Floggit reset --hard %h')<CR>")

					-- git absorb
					nmap("gaa", ":Floggit absorb<space>", { buffer = buf })
					nmap("gar", ":Floggit absorb --and-rebase<space>", { buffer = buf })
					nmap("gab", "<cmd><C-U>exec flog#Format('Floggit absorb --base %h')<CR>")
					nmap("gabr", "<cmd><C-U>exec flog#Format('Floggit absorb --base %h --and-rebase')<CR>")
				end,
			})
		end,
		cmd = { "Flog", "Flogsplit", "Floggit" },
	},
	{
		"sindrets/diffview.nvim",
		enabled = false,
		init = function()
			set_hls({
				DiffviewStatusAdded = { link = "Added" },
				DiffviewStatusModified = { link = "Changed" },
				DiffviewStatusDeleted = { link = "Removed" },
				-- DiffviewFilePanelDeletions = { link = "Removed" },
				-- DiffviewFilePanelInsertions = { link = "Added" },
			})

			api.nvim_create_autocmd("User", {
				pattern = { "DiffviewDiffBufRead" },
				callback = function(ev)
					local buf_name = vim.api.nvim_buf_get_name(ev.buf)
					local _, directory, hash, filePath = string.match(buf_name, "(diffview://)(.+)/%.git/([%w]+)/(.+)")
					vim.b.diffview_hash = hash
				end,
			})

			api.nvim_create_autocmd("FileType", {
				pattern = { "floggraph", "fugitiveblame" },
				callback = function(ev)
					vim.keymap.set("n", "dd", ".DiffviewOpen<end>^!<cr>", { remap = true, buffer = ev.buf })
				end,
			})

			api.nvim_create_autocmd("User", {
				pattern = { "FugitiveTag", "FugitiveCommit" },
				callback = function(ev)
					vim.keymap.set("n", "dd", ":<C-r><C-g>^!<home>DiffviewOpen <cr>", { remap = true, buffer = ev.buf })
				end,
			})

			do -- vim-flagship
				_G.DiffviewReal = function(file)
					if file == "diffview://null" then
						return "null"
					end
					-- local _, _, panel_id, panel_name = file:find([[^diffview:///panels/(%d)/(.*)]])
					-- if panel_name then
					-- 	return panel_name
					-- end
					local _, _, cwd, tab_page, commit_log = file:find([[^diffview://(.*)/%.git/log/(%d)/(.*)]])
					if commit_log then
						-- return string.format("tab(%d):%s", tab_page, commit_log)
						return commit_log
					end
					local _, _, cwd, revision, relpath = file:find([[^diffview://(.*)/%.git/(%x-)/(.*)]])
					if cwd and relpath then
						return string.format("%s/%s", cwd, relpath)
					end
					local _, _, cwd, revision, relpath = file:find([[^diffview://(.*)/%.git/:(%d):/(.*)]])
					if cwd and relpath then
						return string.format("%s/%s", cwd, relpath)
					end
					return file
				end

				_G.DiffviewStatusline = function()
					local diffview_str = "[Diffview(%s)]"
					local file = vim.fn.bufname()
					if file == "diffview://null" then
						return diffview_str:format("null")
					end
					local _, _, panel_id, panel_name = file:find([[^diffview:///panels/(%d)/(.*)]])
					if panel_name then
						return diffview_str:format(panel_name:gsub("^Diffview", ""))
					end
					local _, _, cwd, tab_page, commit_log = file:find([[^diffview://(.*)/%.git/log/(%d)/(.*)]])
					if commit_log then
						return diffview_str:format(commit_log)
					end
					local _, _, cwd, revision, relpath = file:find([[^diffview://(.*)/%.git.*/(%x-)/(.*)]])
					if revision then
						return diffview_str:format(revision)
					end
					local _, _, cwd, stage, relpath = file:find([[^diffview://(.*)/%.git.*/:(%d):/(.*)]])
					if cwd and relpath then
						local stages = {
							-- stage number (0 to 3)
							["0"] = "Index",
							["1"] = "Base", -- Common ancestor
							["2"] = "Ours", -- Target: the branch you're merging into
							["3"] = "Theirs", -- Merged: the branch you're merging from
						}
						return diffview_str:format(stage .. ":" .. stages[stage])
					end
					return ""
				end

				vim.cmd([[
					function! DiffviewReal(...) abort
					  let file = a:0 ? a:1 : @%
					  if file =~# '^\a\a\+:' || a:0 > 1
						return v:lua.DiffviewReal(file)
					  else
						return fnamemodify(file, ':p' . (file =~# '[\/]$' ? '' : ':s?[\/]$??'))
					  endif
					endfunction

					autocmd User Flags call Hoist("buffer", 4, "%{v:lua.DiffviewStatusline()}")
				]])
			end
		end,
		-- opts = {},
		opts = function()
			local actions = require("diffview.config").actions
			return {
				show_help_hints = false,
				file_panel = {
					win_config = { position = "bottom", height = 12 },
				},
				file_history_panel = {
					win_config = { position = "bottom", height = 12 },
				},
				keymaps = {
					-- ~/.local/share/nvim/lazy/diffview.nvim/lua/diffview/config.lua
					disable_defaults = true,
					view = {
						{ "n", "<c-n>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
						{ "n", "<c-p>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
						{ "n", "gf", actions.focus_files, { desc = "Bring focus to the file panel" } },
						{ "n", "<cr>", actions.goto_file_edit, { desc = "Open the file in the previous tabpage" } },
						{ "n", "yuf", actions.toggle_files, { desc = "Toggle the file panel." } },
						-- conflict
						{ "n", "[x", actions.prev_conflict, { desc = "Merge-tool: jump to the previous conflict" } },
						{ "n", "]x", actions.next_conflict, { desc = "Merge-tool: jump to the next conflict" } },
						-- cycle layout
						{ "n", "<c-g><C-x>", actions.cycle_layout, { desc = "Cycle through available layouts." } },
						unpack(actions.compat.fold_cmds),
					},
					file_panel = {
						{ "n", "g?", actions.help("file_panel"), { desc = "Open the help panel" } },
						{ "n", "<c-n>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
						{ "n", "<c-p>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
						{ "n", "<cr>", actions.select_entry, { desc = "Open the diff for the selected entry" } },
						{ "n", "gf", actions.focus_files, { desc = "Bring focus to the file panel" } },
						{ "n", "yuf", actions.toggle_files, { desc = "Toggle the file panel." } },
						-- conflict
						{ "n", "[x", actions.prev_conflict, { desc = "Go to the previous conflict" } },
						{ "n", "]x", actions.next_conflict, { desc = "Go to the next conflict" } },
						-- fold stuff
						{ "n", "zo", actions.open_fold, { desc = "Expand fold" } },
						{ "n", "zc", actions.close_fold, { desc = "Collapse fold" } },
						{ "n", "za", actions.toggle_fold, { desc = "Toggle fold" } },
						{ "n", "zR", actions.open_all_folds, { desc = "Expand all folds" } },
						{ "n", "zM", actions.close_all_folds, { desc = "Collapse all folds" } },
						-- cycle layout
						{ "n", "<c-g><C-x>", actions.cycle_layout, { desc = "Cycle through available layouts." } },
					},
					file_history_panel = {
						{ "n", "g!", actions.options, { desc = "Open the option panel" } },
						{ "n", "g?", actions.help("file_history_panel"), { desc = "Open the help panel" } },
						{ "n", "<c-n>", actions.select_next_entry, { desc = "Open the diff for the next file" } },
						{ "n", "<c-p>", actions.select_prev_entry, { desc = "Open the diff for the previous file" } },
						{ "n", "<cr>", actions.select_entry, { desc = "Open the diff for the selected entry" } },
						{ "n", "gf", actions.focus_files, { desc = "Bring focus to the file panel" } },
						{ "n", "yuf", actions.toggle_files, { desc = "Toggle the file panel." } },
						-- fold stuff
						{ "n", "zo", actions.open_fold, { desc = "Expand fold" } },
						{ "n", "zc", actions.close_fold, { desc = "Collapse fold" } },
						{ "n", "za", actions.toggle_fold, { desc = "Toggle fold" } },
						{ "n", "zR", actions.open_all_folds, { desc = "Expand all folds" } },
						{ "n", "zM", actions.close_all_folds, { desc = "Collapse all folds" } },
						-- cycle layout
						{ "n", "<c-g><C-x>", actions.cycle_layout, { desc = "Cycle through available layouts." } },
					},
					option_panel = {
						{ "n", "<cr>", actions.select_entry, { desc = "Change the current option" } },
						{ "n", "q", actions.close, { desc = "Close the panel" } },
					},
					help_panel = {
						{ "n", "q", actions.close, { desc = "Close help menu" } },
					},
				},
			}
		end,
		cmd = {
			"DiffviewOpen",
			"DiffviewFileHistory",
		},
		keys = {
			-- { "\\d", ":DiffviewOpen " },
			-- { "d.", ":DiffviewOpen " },
			-- { "dO", "<cmd>DiffviewOpen<cr>" },
			-- { "dY", "<cmd>DiffviewFileHistory %<cr>" },
		},
	},
	-- }}}
}
