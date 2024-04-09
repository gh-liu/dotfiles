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
local toggle_fugitive = function()
	if fugitivebuf > 0 then
		api.nvim_buf_call(fugitivebuf, function()
			vim.cmd([[normal gq]])
		end)
		fugitivebuf = -1
	else
		vim.cmd.G({ mods = {
			keepalt = true,
			keepjumps = true,
		} })
	end
end

keymap.set("n", "<leader>gg", toggle_fugitive, { silent = true })
keymap.set("n", "g<space>", toggle_fugitive, { silent = true })

keymap.set("n", "<leader>ge", "<cmd>Gedit<cr>")
keymap.set("n", "<leader>gw", "<cmd>Gwrite<cr>")

local stash_list_cmd = "--paginate stash list '--pretty=format:%h %as %<(10)%gd %<(76,trunc)%s'"
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

		keymap.set("n", "q", "gq", { buffer = fugitivebuf, remap = true })
		-- stash
		keymap.set("n", "czl", ":G " .. stash_list_cmd .. "<CR>", { buffer = fugitivebuf })

		-- git absorb
		keymap.set("n", "gaa", ":Git absorb<space>", { buffer = fugitivebuf })
	end,
})

autocmd("User", {
	group = g,
	pattern = { "FugitivePager" },
	callback = function(data)
		local buf = data.buf

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

		keymap.set("n", "czd", function()
			op_stash(function(idx)
				vim.cmd("Git stash drop --quiet " .. idx)
			end)
		end, { buffer = buf })
		keymap.set("n", "czo", function()
			op_stash(function(idx)
				vim.cmd("Git stash pop --quiet --index " .. idx)
			end)
		end, { buffer = buf })
		keymap.set("n", "czO", function()
			op_stash(function(idx)
				vim.cmd("Git stash pop --quiet " .. idx)
			end)
		end, { buffer = buf })
	end,
})

autocmd("User", {
	group = g,
	pattern = { "FugitiveStageBlob" },
	callback = function(data)
		local buf = data.buf
		local buf_name = api.nvim_buf_get_name(buf)
		local _, _, stage, _ = buf_name:find([[^fugitive://.*/%.git.*/(%x-)/(.*)]])
		vim.b[buf].fugitive_stage_type = stage
	end,
})

-- jump up to the commit object for the current tree or blob
autocmd("User", {
	group = g,
	pattern = {
		"FugitiveTree",
		"FugitiveBlob",
	},
	callback = function(data)
		local buf = data.buf
		keymap.set("n", "<space>.", "<cmd>edit %:h<CR>", { buffer = buf })
	end,
})

-- local fugitive_object_type = {
-- 	FugitiveTag = "tag",
-- 	FugitiveCommit = "commit",
-- 	FugitiveTree = "tree",
-- 	FugitiveBlob = "blob",
-- }

-- autocmd("User", {
-- 	group = g,
-- 	pattern = vim.tbl_keys(fugitive_object_type),
-- 	callback = function(data)
-- 		local buf = data.buf
-- 		-- use vim.b.fugitive_type instead
-- 		vim.b[buf].fugitive_object_type = fugitive_object_type[data.match]
-- 	end,
-- })

-- autocmd("User", {
-- 	group = g,
-- 	pattern = { "FugitiveObject" },
-- 	callback = function(data)
-- 		local buf = data.buf
-- 		local buf_name = api.nvim_buf_get_name(buf)
-- 		vim.print(vim.fn["fugitive#Parse"](buf_name))
-- 	end,
-- })
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
	-- GListDiffFiles = [[:G difftool --name-status]],
	Gdiff4 = function(_)
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
	Gdiff3Toggle = function(_)
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
	Gdiff3HSW = function()
		--- { HEAD, stage/index, working copy } with diff between HEAD v.s. index

		local cursor = vim.api.nvim_win_get_cursor(0)

		vim.cmd([[ tabnew % ]])
		-- turn off diff for all windows
		vim.cmd([[ diffoff! ]])
		local win = vim.api.nvim_get_current_win() -- on a new tab
		vim.api.nvim_win_set_cursor(win, cursor) -- preserve the same cursor location

		vim.cmd([[ aboveleft Gvdiff HEAD ]]) -- left: HEAD
		vim.fn.win_gotoid(win)
		vim.cmd([[ above Gvdiff :%]]) -- middle: stage/index
		vim.fn.win_gotoid(win)
		vim.cmd([[ diffoff ]]) -- right: working copy (no diff)
		-- vim.cmd([[ set cursorbind ]]) -- right: working copy (cursorbind)
	end,
	Gstashtool = function()
		vim.cmd([[Gclog -g stash]])
		-- browse stashs and apply using cz<Space>apply<Space><C-R><C-G>
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

--- Get a human-readable ref name (e.g. master, master~1, remotes/origin/HEAD) for a commit hash,
--- from the output of `git name-rev`. Returns nil if the reference cannot be resolved,
--- or "undefined" if no named reference is found (i.e. dangling or detached commit).
--- This function may be called quite frequently (statusline), so needs to cache the result.
---@type function(sha: string, git_path?: string): string|nil
local name_revision = (function()
	local cache = {}
	local function memoize(fn)
		return function(sha, git_path)
			local ret = (cache[git_path] or {})[sha]
			if ret then
				return ret[1]
			end

			ret = { fn(sha, git_path) }
			if git_path == nil then
				git_path = vim.fn.getcwd(0)
			end
			cache[git_path] = cache[git_path] or {}
			cache[git_path][sha] = ret
			return ret[1]
		end
	end
	vim.api.nvim_create_autocmd("User", {
		pattern = "FugitiveChanged",
		group = vim.api.nvim_create_augroup("fugitive-revision-cache", { clear = true }),
		callback = function()
			-- invalidate all the cache on git operations
			for k, _ in pairs(cache) do
				cache[k] = nil
			end
		end,
	})

	return memoize(function(sha, git_path)
		local args = { "name-rev", sha, "--name-only" }
		local ret

		if git_path then
			git_path = vim.fn.FugitiveExtractGitDir(vim.fn.expand(git_path))
			ret = vim.fn.FugitiveExecute(args, git_path).stdout
		else
			ret = vim.fn.FugitiveExecute(args).stdout
		end
		ret = vim.trim(table.concat(ret, ""))
		if #ret == 0 then
			return nil
		else
			return ret
		end
	end)
end)()
