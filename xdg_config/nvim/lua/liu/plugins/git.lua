local api = vim.api
local utils = require("liu.utils")

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
			utils.set_hls({
				diffAdded = { link = "DiffAdd" },
				-- diffAdded = { fg = "#4f5a58" },
				-- diffRemoved = { link = "DiffDelete" },
				diffRemoved = { fg = "#634652" },
				-- StatusLineFugitive = { link = "PmenuShadow" },
				StatusLineFugitive = { bg = "#546e91" },
			})

			--[[ Autocmds ]]
			local augroup = utils.augroup("fugitive")
			-- FileType: git / fugitive common settings
			api.nvim_create_autocmd("FileType", {
				group = augroup,
				pattern = { "git", "fugitive" },
				callback = function()
					vim.wo[0][0].foldmethod = "syntax"

					vim.bo.bufhidden = "wipe"
					vim.bo.buflisted = false

					if vim.b.fugitive_type == "commit" then
						-- fold all files
						vim.wo[0][0].foldlevel = 0
					end
				end,
			})
			api.nvim_create_autocmd("User", {
				group = augroup,
				pattern = { "FugitiveIndex", "FugitiveObject", "FugitiveStageBlob" },
				callback = function()
					vim.wo[0][0].winhighlight = "StatusLine:StatusLineFugitive"
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
					vim.keymap.set("n", "cob", ":Git checkout -b ", { buffer = 0, desc = "Git checkout new branch" })
					-- Absorb (cargo install git-absorb)
					vim.keymap.set("n", "gaa", ":Git absorb<space>", { buffer = 0, desc = "Git absorb" })
					vim.keymap.set("n", "gar", ":Git absorb --and-rebase<space>", { buffer = 0, desc = "Git absorb and rebase" })
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
			utils.set_cmds({
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
		-- integrates with: vim-fugitive (same Git commands)
		-- note: absorb keymaps (gaa/gar) overlap with fugitive buffer keymaps
		init = function(self)
			vim.g.flog_use_internal_lua = 1
			vim.g.flog_default_opts = { max_count = 2000 }
			vim.g.flog_permanent_default_opts = { date = "format:%Y-%m-%d %H:%m" }

			-- keymap.set("ca", "F", "Flog", {})
			vim.keymap.set("ca", "F", "Flogsplit", {})

			api.nvim_create_autocmd("FileType", {
				group = utils.augroup("flog/setup"),
				pattern = "floggraph",
				callback = function(ev)
					local buf = ev.buf
					local nmap = function(lhs, rhs, opts)
						opts = opts or { buffer = buf, silent = true }
						vim.keymap.set("n", lhs, rhs, opts)
					end

					nmap("o", "<Plug>(FlogVSplitCommitRight)", { desc = "Open commit" })
					nmap("q", "<Plug>(FlogQuit)", { desc = "Quit flog" })

					-- :h flog-%h
					-- The hash of the commit under the cursor, if any.

					-- git reset --mixed/hard
					nmap("cRm", "<Cmd>exec flog#Format('Floggit reset %h')<CR>", { desc = "Git reset to commit" })
					nmap("cRh", "<Cmd>exec flog#Format('Floggit reset --hard %h')<CR>", { desc = "Git reset --hard to commit" })

					-- git absorb (note: overlaps with fugitive buffer keymaps)
					nmap("gaa", ":Floggit absorb<space>", { buffer = buf, desc = "Flog git absorb" })
					nmap("gar", ":Floggit absorb --and-rebase<space>", { buffer = buf, desc = "Flog git absorb and rebase" })
					nmap("gab", "<cmd><C-U>exec flog#Format('Floggit absorb --base %h')<CR>", { desc = "Flog git absorb --base" })
					nmap("gabr", "<cmd><C-U>exec flog#Format('Floggit absorb --base %h --and-rebase')<CR>", { desc = "Flog git absorb --base and rebase" })
				end,
			})
		end,
		cmd = { "Flog", "Flogsplit", "Floggit" },
	},
	-- }}}
}
