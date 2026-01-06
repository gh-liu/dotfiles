local api = vim.api

---@param cmds table<string, string|function>
local set_cmds = function(cmds, opts)
	opts = opts or { bang = true, nargs = 0 }
	for key, cmd in pairs(cmds) do
		vim.api.nvim_create_user_command(key, cmd, opts)
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
		dependencies = {
			"tpope/vim-rhubarb",
			-- { "shumphrey/fugitive-gitlab.vim" },
			{
				"justinmk/vim-ug",
				config = function()
					vim.cmd([[
						" gitsigns
						nunmap Un
						nunmap UN
						nunmap <c-n>
						nunmap <c-p>
						nmap Ubb 1Ub
						nmap UL 9Ul
					]])
				end,
			},
			{ "gh-liu/vim-qfugitive", dev = true },
		},
		config = function()
			--[[ Mappings remap ]]
			-- https://github.com/tpope/vim-fugitive/issues/1080#issuecomment-521100430
			vim.g.oremap = { ["[m"] = "[f", ["]m"] = "]f" }
			vim.g.xremap = { ["[m"] = "[f", ["]m"] = "]f" }
			vim.g.nremap = { ["[m"] = "[f", ["]m"] = "]f", ["="] = "<TAB>" }

			--[[ Highlights ]]
			set_hls({
				diffAdded = { link = "DiffAdd" },
				-- diffAdded = { fg = "#4f5a58" },
				-- diffRemoved = { link = "DiffDelete" },
				diffRemoved = { fg = "#634652" },
				-- StatusLineFugitive = { link = "PmenuShadow" },
				StatusLineFugitive = { bg = "#546e91" },
			})

			--[[ Autocmds ]]
			local augroup = vim.api.nvim_create_augroup("liu/fugitive", { clear = true })
			-- FileType: git / fugitive common settings
			api.nvim_create_autocmd("FileType", {
				group = augroup,
				pattern = { "git", "fugitive" },
				callback = function()
					vim.wo[0][0].foldmethod = "syntax"
					vim.wo[0][0].winhighlight = "StatusLine:StatusLineFugitive"

					vim.bo.bufhidden = "wipe"
					vim.bo.buflisted = false

					if vim.b.fugitive_type == "commit" then
						-- fold all files
						vim.wo[0][0].foldlevel = 0
					end
				end,
			})

			-- FileType: fugitive (reset mappings)
			api.nvim_create_autocmd("FileType", {
				group = augroup,
				pattern = "fugitive",
				callback = function()
					vim.cmd([[
						nnoremap <buffer> rt :<C-U>Git reset @~<C-R>=v:count1<CR><CR>
						nnoremap <buffer> rT :<C-U>Git reset --hard @~<C-R>=v:count1<CR><CR>
					]])

					-- Checkout -b
					vim.keymap.set("n", "cob", ":Git checkout -b ", { buffer = 0 })
					-- Absorb (cargo install git-absorb)
					vim.keymap.set("n", "gaa", ":Git absorb<space>", { buffer = 0 })
					vim.keymap.set("n", "gar", ":Git absorb --and-rebase<space>", { buffer = 0 })
				end,
			})

			--[[ Toggle summary window ]]
			local function make_fugitive_toggler(augroup)
				local buf = -1
				local function toggle()
					if buf > 0 then
						api.nvim_buf_call(buf, function()
							vim.cmd("bw!")
						end)
					else
						vim.cmd.G({ mods = { keepalt = true } })
					end
				end

				api.nvim_create_autocmd("User", {
					group = augroup,
					pattern = "FugitiveIndex",
					callback = function(data)
						buf = data.buf
						api.nvim_create_autocmd("BufWipeout", {
							callback = function()
								buf = -1
							end,
							buffer = buf,
						})
					end,
				})

				return toggle
			end
			local G_toggle = make_fugitive_toggler(augroup)
			vim.keymap.set("n", "g<space>", G_toggle, { silent = true, desc = "Toggle fugitive summary" })

			--[[ Custom commands ]]
			set_cmds({
				GLog = "Gclog!",

				GConflict = "tabnew % | Gvdiffsplit! | Gvdiffsplit! :1 | wincmd J",
			})
			-- GFiles [object]: show files changed in working tree, index, or commit
			vim.cmd([[
				command! -bang -nargs=? GFiles exec 'G difftool --name-only ' .
					\ (<q-args> ==# ':' ? '--cached' :
					\  <q-args> ==# '' && fugitive#Object('%') =~# '^[0-9a-f]' ? fugitive#Object('%') . '~ ' . fugitive#Object('%') :
					\  <q-args> ==# '' ? '' :
					\  <q-args> =~# '^@' ? (<q-args> ==# '@' ? '@~ @' : <q-args> . '~ ' . <q-args>) :
					\  <q-args> . '~ ' . <q-args>)
			]])
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
	-- }}}
}
