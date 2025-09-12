local api = vim.api

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
			vim.keymap.set("n", "<leader>gb", "<cmd>G blame<cr>")
			vim.keymap.set("n", "<leader>gl", "<cmd>Gclog! %<cr>")
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
					vim.keymap.set("n", "q", "<cmd>bw!<cr>", { buffer = buf })
				end,
			})

			--- Toggle summary window {{{3
			-- TODO: multiply tabs not work
			local G = {
				buf = -1,
				toggle = function(self)
					if self.buf > 0 then
						api.nvim_buf_call(self.buf, function()
							vim.cmd("bw!")
							self.buf = -1
						end)
					else
						vim.cmd.G({ mods = { keepalt = true } })
					end
				end,
			}

			api.nvim_create_autocmd("User", {
				group = g,
				pattern = { "FugitiveIndex" },
				callback = function(data)
					vim.bo.bufhidden = "wipe"
					vim.bo.buflisted = false

					G.buf = data.buf
					api.nvim_create_autocmd("BufWipeout", {
						callback = function()
							G.buf = -1
						end,
						buffer = data.buf,
					})
				end,
			})

			vim.keymap.set("n", "g<space>", function()
				G:toggle()
			end, { silent = true })
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

			vim.api.nvim_create_user_command("GStashList", function()
				local cmd = { "git", "stash", "list", "--pretty=format:%H %<(10)%gd %<(76,trunc)%s" }
				local obj = vim.system(cmd, { text = true }):wait()
				local lines = vim.split(obj.stdout, "\n")

				local dir = vim.fn["FugitiveGitDir"]()
				local qfitems = {}
				for _, line in ipairs(lines) do
					local hash, stash_id, message = line:match("^(%x+)%s+(%g+)%s+(.*)$")
					table.insert(qfitems, {
						module = hash,
						filename = string.format("fugitive://%s//%s", dir, hash),
						text = message,
					})
				end
				if #qfitems > 0 then
					vim.fn.setqflist(qfitems)
					vim.cmd.copen()
				end
			end, { nargs = 0 })
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
						"GCFiles",
						":let commit=fugitive#Object(@%) | exec 'G<bang> difftool --name-only ' .. commit .. '~' .. ' '.. commit",
						{ bang = true }
					)
					vim.wo[0][0].foldlevel = 0
				end,
			})

			set_cmds({
				GFiles = "G<bang> difftool --name-only",
				GFiles0 = "G<bang> difftool --name-only --cached",
				-- 3 way diff
				-- https://dzx.fr/blog/introduction-to-vim-fugitive/#3-way-diff
				GConflict = "tabnew % | Gvdiffsplit! | Gvdiffsplit! :1 | wincmd J",
			})
			vim.keymap.set({ "n" }, "yqg", "<cmd>GFiles<cr>", {})

			-- NOTE: review workflow
			-- 0. review between @ and FETCH_HEAD or 1st args
			-- 1. checkout remote branch
			-- 2. checkout back to master branch
			set_cmds({
				-- 3. GRcommit to show commits
				-- 3.1 there is a `Gfiles` command to show files of current commit
				GRCommit = 'let g:diff_target = get(g:, "diff_target", len(<q-args>)==0?"FETCH_HEAD":<q-args>)'
					.. '| exec "Gclog<bang> @.." .. g:diff_target',
				-- 4. GRfiles to show files
				GRFiles = 'let g:diff_target = get(g:, "diff_target", len(<q-args>)==0?"FETCH_HEAD":<q-args>)'
					.. '| let g:diff_base = trim(execute("G merge-base @ " .. g:diff_target))'
					.. '| exec "G<bang> difftool --name-status " .. g:diff_base ..  " " .. g:diff_target',
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

			-- skip and do it by myself
			vim.g.flagship_skip = "^FugitiveStatusline$"
			vim.cmd([[
				"autocmd User Flags call Hoist('buffer', 5, function('FugitiveStatusline'))
				autocmd User Flags call Hoist('buffer', 6, '%{FugitiveStatusline()}')
				autocmd User Flags call Hoist('buffer', 7, '%{flagship#surround(toupper(get(b:,"fugitive_type","")))}', {"hl":"ErrorMsg"})
			]])

			set_hls({
				diffAdded = { link = "DiffAdd" },
				diffRemoved = { link = "DiffDelete" },
			})
		end,
	},
	{
		"rbong/vim-flog",
		enabled = false,
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
	-- }}}
}
