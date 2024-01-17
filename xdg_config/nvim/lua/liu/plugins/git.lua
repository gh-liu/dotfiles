local api = vim.api
local keymap = vim.keymap
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local g = augroup("liu/fugitive", { clear = true })

-- Toggle summary window {{{3
local fugitivebuf = -1
local exit = function()
	api.nvim_buf_delete(fugitivebuf, { force = true })
end
keymap.set("n", "<leader>gg", function()
	if fugitivebuf > 0 then
		exit()
		fugitivebuf = -1
	else
		vim.cmd.G({ mods = { keepalt = true } })
	end
end, { silent = true })

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
	GUndoLastCommit = [[:G reset --soft HEAD~]],
	GDiscardChanges = [[:G reset --hard]],
	Gdiffsplit3 = function(t)
		vim.cmd([[ tabnew % ]])
		-- The windows layout:
		-- Top-left: "ours" corresponding to the HEAD.
		-- Top-center: "base" corresponding to the common ancestor of main and merge-branch.
		-- Top-right: "theirs" corresponding to the tip of merge-branch.
		-- Bottom: the working copy.

		-- starts a diff between the current file and the object `:1`
		-- the doc states that `:1:%` corresponds to the current file's common ancestor during a conflict
		-- with % indicating the current file, which the default when omitted
		vim.cmd("Gdiffsplit :1")
		-- starts a vertical diff between the current file and all its direct ancestors
		vim.cmd("Gvdiffsplit!")
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
