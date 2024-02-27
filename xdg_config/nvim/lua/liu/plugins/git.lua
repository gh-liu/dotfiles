local api = vim.api
local keymap = vim.keymap
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

--[[ 
-- NOTE: fugitive
https://github.com/tpope/vim-fugitive/discussions/1661#discussioncomment-306777
`>` is a special notation to use the current filename.

Think of reblame as navigating to a commit and then running blame on your file.
1. `-` use the commit in question under your cursor and reblame the file.
2. `~` Is equivalent to `<rev>~`
3. `P` Is equivalent to `<rev>^`

]]

local g = augroup("liu/fugitive", { clear = true })

-- Toggle summary window {{{3
local fugitivebuf = -1
local exit = function()
	api.nvim_buf_delete(fugitivebuf, { force = true })
end
local toggle_fugitive = function()
	if fugitivebuf > 0 then
		exit()
		fugitivebuf = -1
	else
		vim.cmd.G({ mods = { keepalt = true } })
	end
end

keymap.set("n", "<leader>gg", toggle_fugitive, { silent = true })
keymap.set("n", "g<space>", toggle_fugitive, { silent = true })

autocmd("User", {
	group = g,
	pattern = { "FugitiveIndex" },
	callback = function(data)
		fugitivebuf = data.buf
		autocmd("BufDelete", {
			callback = function()
				fugitivebuf = -1
			end,
			buffer = data.buf,
		})

		keymap.set("n", "q", function()
			exit()
		end, { buffer = fugitivebuf })
	end,
})
-- }}}

autocmd("BufEnter", {
	group = g,
	pattern = { "fugitive:///*" },
	callback = function(ev)
		vim.b[ev.buf].disable_winbar = true
	end,
})

set_cmds({
	-- GUndoLastCommit = [[:G reset --soft HEAD~]],
	-- GDiscardChanges = [[:G reset --hard]],
	GDiffFiles = [[G difftool --name-status]],
	GConflictTool = function(t)
		vim.cmd([[ tabnew % ]])
		-- The windows layout:
		-- Top-left: "ours" corresponding to the HEAD.
		-- Top-center: "base" corresponding to the common ancestor of main and merge-branch.
		-- Top-right: "theirs" corresponding to the tip of merge-branch.
		-- Bottom: the working copy.

		-- starts a diff between the current file and the object `:1`
		-- the doc states that `:1:%` corresponds to the current file's common ancestor during a conflict
		-- with % indicating the current file, which the default when omitted
		-- :h Gdiffsplit
		vim.cmd("Gdiffsplit :1") -- (top, current window) base, (bottom) current file
		-- during a merge conflict, this is a three-way diff against the "ours" and "theirs" ancestors.
		-- :h Gdiffsplit!
		vim.cmd("Gvdiffsplit!") -- (left) ours, (mid, current window) base, (right) theirs
	end,
})

set_cmds({
	GdiffToggle = function(opt)
		if vim.o.diff then
			vim.cmd("diffoff")
			for _, bufnr in ipairs(api.nvim_list_bufs()) do
				if api.nvim_buf_get_name(bufnr):match("fugitive://.*") then
					api.nvim_buf_delete(bufnr, { force = true })
				end
			end
		else
			vim.cmd("Gvdiffsplit!")

			local diff_get2 = "<c-h>"
			local diff_get3 = "<c-l>"
			local opts = { buffer = api.nvim_get_current_buf() }
			keymap.set("n", diff_get2, ":diffget //2<cr>", opts)
			keymap.set("n", diff_get3, ":diffget //3<cr>", opts)

			autocmd("OptionSet", {
				group = augroup("liu/option_set_diff", { clear = true }),
				pattern = "diff",
				callback = function(ev)
					if vim.v.option_old then
						-- print("off")
						pcall(keymap.del, "n", diff_get2, opts)
						pcall(keymap.del, "n", diff_get3, opts)
					end
				end,
				once = true,
				desc = "OptionSetDiff",
			})
		end
	end,
})

local add = get_hl("DiffAdd").fg
local change = get_hl("DiffChange").fg
local text = get_hl("DiffText").fg

set_hls({
	-- gitDiff = { link = "Normal" },
	diffFile = { fg = text, italic = true },
	diffNewFile = { fg = add, italic = true },
	diffOldFile = { fg = change, italic = true },
	diffAdded = { link = "DiffAdd" },
	diffRemoved = { link = "DiffDelete" },
	diffLine = { link = "Visual" },
	diffIndexLine = { link = "VisualNC" },
})

-- set_cmds({
-- 	GDiffFiles = function(opts)
-- 		local file_status = {
-- 			A = "Added",
-- 			B = "Broken",
-- 			C = "Copied",
-- 			D = "Deleted",
-- 			M = "Modified",
-- 			R = "Renamed",
-- 			T = "Changed",
-- 			U = "Unmerged",
-- 			X = "Unknown",
-- 		}
-- 		local r = vim.system({ "git", "diff", "--name-status" }, { text = true }):wait()
-- 		if #r.stderr > 0 then
-- 			vim.print(r.stderr)
-- 			return
-- 		end
-- 		local diffs = vim.split(r.stdout, "\n", { trimempty = true })
-- 		diffs = vim.iter(diffs)
-- 			:map(function(f)
-- 				local _, _, status, file = string.find(f, "(%a+)%s(.+)")
-- 				return {
-- 					filename = file,
-- 					text = file_status[status],
-- 				}
-- 			end)
-- 			:totable()

-- 		vim.fn.setqflist(diffs)
-- 		vim.cmd.copen()
-- 	end,
-- })
