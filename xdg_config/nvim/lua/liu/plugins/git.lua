local api = vim.api
local utils = require("liu.utils")

return { -- Git {{{2
	-- Git wrapper providing :G commands for commit/diff/blame/log operations
	{
		"tpope/vim-fugitive",
		dependencies = {
			-- GitHub integration for vim-fugitive (gbrowse command)
			"tpope/vim-rhubarb",
			-- { "shumphrey/fugitive-gitlab.vim" },
			-- Fugitive undo graph visualization plugin
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
			-- Quickfix integration for fugitive git operations
			{ "gh-liu/vim-qfugitive", dev = true },
		},
		config = function()
			--[[ Mappings remap ]]
			-- https://github.com/tpope/vim-fugitive/issues/1080#issuecomment-521100430
			vim.g.oremap = { ["[m"] = "[f", ["]m"] = "]f" }
			vim.g.xremap = { ["[m"] = "[f", ["]m"] = "]f" }
			vim.g.nremap = { ["[m"] = "[f", ["]m"] = "]f", ["="] = "<TAB>" }

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

						nnoremap <buffer> cob :<C-U>Git checkout -b<space>

						"cargo install git-absorb
						nnoremap <buffer> gaa :<C-U>Git absorb<space>
						nnoremap <buffer> gar :<C-U>Git absorb --and-rebase<space>
					]])
				end,
			})

			--[[ Toggle summary window ]]
			local function make_fugitive_toggler(augroup)
				local function toggle()
					local buf = vim.t.fugitive_buf or -1

					if buf > 0 and api.nvim_buf_is_valid(buf) then
						api.nvim_buf_call(buf, function()
							vim.cmd("bw!")
						end)
						vim.t.fugitive_buf = -1
					else
						vim.cmd.G({ mods = { keepalt = true } })
					end
				end

				api.nvim_create_autocmd("User", {
					group = augroup,
					pattern = "FugitiveIndex",
					callback = function(data)
						vim.t.fugitive_buf = data.buf
						api.nvim_create_autocmd("BufWipeout", {
							callback = function()
								vim.t.fugitive_buf = -1
							end,
							buffer = data.buf,
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
	-- Git log graph viewer with branch visualization and commit operations
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
					local function nmap(lhs, rhs, desc)
						vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
					end

					-- :h flog-%h (hash under cursor)
					local maps = {
						{ "o", "<Plug>(FlogVSplitCommitRight)", "Open commit" },
						{ "q", "<Plug>(FlogQuit)", "Quit flog" },
						{ "rt", "<Cmd>exec flog#Format('Floggit reset %h')<CR>", "Git reset to commit" },
						{ "rT", "<Cmd>exec flog#Format('Floggit reset --hard %h')<CR>", "Git reset --hard to commit" },
						{ "gaa", ":Floggit absorb<space>", "Flog git absorb" },
						{ "gar", ":Floggit absorb --and-rebase<space>", "Flog git absorb and rebase" },
						{
							"gab",
							"<Cmd><C-U>exec flog#Format('Floggit absorb --base %h')<CR>",
							"Flog git absorb --base",
						},
						{
							"gabr",
							"<Cmd><C-U>exec flog#Format('Floggit absorb --base %h --and-rebase')<CR>",
							"Flog git absorb --base and rebase",
						},
					}

					for _, m in ipairs(maps) do
						nmap(m[1], m[2], m[3])
					end
				end,
			})
		end,
		cmd = { "Flog", "Flogsplit", "Floggit" },
	},
	-- }}}
}
