-- CmdAtom-driven enhancements.
-- See |CmdAtom| and the worked examples in |repeat.txt|.

-- ====================================================================
-- 1. "." in operator-pending mode repeats the last motion, so "d.",
--    "y.", "c." operate on the repeated motion (motion-repeat in
--    |repeat.txt|: "3w", "fx", "/pat<CR>", ...). Replay resolved keys
--    without remapping, or the original input when capture was lossy.
--    CmdAtom is deferred, so only motions already delivered can be repeated.
-- ====================================================================
local motion
local function remember_motion(atom)
	if atom.changed then
		return
	elseif atom.type == "motion" then
		motion = atom
	elseif atom.type == "mapping" then
		-- Composite mappings may contain Normal-only setup, e.g. ms/beta<CR>.
		-- Keep the motion itself so it is valid after an operator as well.
		for _, step in ipairs(atom.atoms or {}) do
			remember_motion(step)
		end
	end
end
vim.api.nvim_create_autocmd("CmdAtom", {
	pattern = { "motion", "mapping" },
	callback = function(ev)
		remember_motion(ev.data)
	end,
})
vim.keymap.set("o", ".", function()
	if not motion or motion.keys == "" then
		return ""
	elseif motion.keys then
		return motion.keys
	end
	-- Resolve lossy input again in operator-pending mode.
	vim.api.nvim_feedkeys(motion.lhs, "mi", false)
	return ""
end, { expr = true })

-- ====================================================================
-- 2. Undo/redo change highlight: on `u`/`<C-r>` (or :undo/:redo/:earlier/
--    :later), highlight the lines that changed. CmdAtom detects the
--    undo/redo atom (deferred, i.e. after the change applied);
--    nvim_buf_attach's on_bytes (sync, fires on every text change incl.
--    undo) remembers the affected range, rendered via vim.hl.range — the
--    same machinery hl_op uses, with built-in timeout clearing.
-- ====================================================================
local undo_ns = vim.api.nvim_create_namespace("liu.undo_diff")

local function attach_undo_tracker(buf)
	if vim.b[buf]._undodiff_attached then
		return
	end
	vim.b[buf]._undodiff_attached = true
	local ok, err = pcall(vim.api.nvim_buf_attach, buf, false, {
		on_bytes = function(_, _, _, start_row, start_col, _, old_end_row, old_end_col, _, new_end_row, new_end_col, _)
			if old_end_row == 0 and new_end_row == 0 then
				-- In-line change: char-accurate region in the post-change buffer.
				-- Cols are offsets from start_col when end row is 0 (see
				-- |nvim_buf_attach()|), and the region is end-exclusive.
				local len = math.max(old_end_col, new_end_col)
				local dir = old_end_col < new_end_col and "add" or (old_end_col > new_end_col and "del" or "chg")
				vim.b[buf]._undodiff_last_change =
				{ start_row, start_col, start_row, start_col + math.max(len, 1), dir }
			else
				-- Multi-line change: fall back to linewise region.
				local change_end = start_row + math.max(old_end_row, new_end_row)
				if change_end == start_row then
					change_end = start_row + 1
				end
				local dir = new_end_row > old_end_row and "add" or (old_end_row > new_end_row and "del" or "chg")
				vim.b[buf]._undodiff_last_change = { start_row, 0, change_end, 0, dir }
			end
		end,
	})
end
vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile", "BufRead" }, {
	callback = function(ev)
		attach_undo_tracker(ev.buf)
	end,
})
-- Plugin loaders (pack's VimEnter hooks) can reload buffers and detach
-- attaches made earlier; re-attach everything after VimEnter. BufEnter may
-- also fire before this module is sourced (`nvim file`), hence the sweep.
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			vim.b[buf]._undodiff_attached = nil -- force re-attach
			attach_undo_tracker(buf)
		end
	end,
})

--- Undo/redo atoms: u/<C-r>/g-/g+ (normal) or undo/redo/earlier/later (excmd).
local is_undo_atom = function(d)
	if not d.changed then
		return false
	elseif d.type == "normal" then
		return d.cmd == "u" or d.cmd == "<C-R>" or d.cmd == "g-" or d.cmd == "g+"
	elseif d.type == "excmd" then
		-- Parse the command text to support abbreviations and modifiers without
		-- mistaking unrelated commands such as :undojoin for :undo.
		local ok, cmd = pcall(vim.api.nvim_parse_cmd, d.text or "", {})
		return ok and (cmd.cmd == "undo" or cmd.cmd == "redo" or cmd.cmd == "earlier" or cmd.cmd == "later")
	end
	return false
end

vim.api.nvim_create_autocmd("CmdAtom", {
	callback = function(ev)
		local d = ev.data
		if not is_undo_atom(d) then
			return
		end
		local buf = ev.buf
		local r = vim.b[buf] and vim.b[buf]._undodiff_last_change
		if not (r and vim.api.nvim_buf_is_valid(buf)) then
			return
		end
		local n = vim.api.nvim_buf_line_count(buf)
		local dir = r[5] or "chg"
		if r[1] == r[3] and dir ~= "del" then
			-- Character-accurate in-line change (undo restoring a word, etc.).
			-- Deleted in-line text is gone from the buffer, so deletes fall
			-- back to a linewise marker.
			local hl = dir == "add" and "DiffAdd" or "DiffChange"
			vim.hl.range(buf, undo_ns, hl, { r[1], r[2] }, { r[3], r[4] }, {
				regtype = "v",
				timeout = vim.o.timeoutlen,
			})
		else
			-- Multi-line change or delete: linewise highlight.
			local hl = dir == "del" and "DiffDelete" or (dir == "add" and "DiffAdd" or "DiffChange")
			-- r[3] is end_row: start_row for in-line (r[1]==r[3]), exclusive
			-- change_end for multi-line. Clamp to the last line.
			local end_row = math.max(r[3] - 1, r[1])
			vim.hl.range(buf, undo_ns, hl, { r[1], 0 }, { math.min(end_row, n - 1), vim.v.maxcol }, {
				regtype = "V",
				timeout = vim.o.timeoutlen,
			})
		end
	end,
})

-- ====================================================================
-- 3. Retrospective macro: [count]<leader>@ drafts the last [count] actions
--    in the cmdwin; <Enter> saves it, :q cancels. Without a count,
--    <leader>@ replays the saved macro. Keep at most 20 replayable actions.
-- ====================================================================
local atom_ring = {}
local macro_lhs = vim.keycode("<leader>@")
vim.api.nvim_create_autocmd("CmdAtom", {
	callback = function(ev)
		local atom = ev.data
		if
			atom.keys == ""
			or atom.lhs:gsub("^%d+", "") == macro_lhs
			or not vim.api.nvim_buf_is_valid(ev.buf)
			or vim.fn.getcmdwintype() ~= ""
			or (atom.type == "excmd" and (atom.text or ""):match("^lua%s+vim%.g%.atom_macro%s*="))
		then
			return
		end
		atom_ring[#atom_ring + 1] = atom
		if #atom_ring > 20 then
			table.remove(atom_ring, 1)
		end
	end,
})
vim.keymap.set("n", "<leader>@", function()
	local count = vim.v.count
	-- Let pending CmdAtom events reach the ring before reading it.
	vim.schedule(function()
		if count == 0 then
			if not vim.g.atom_macro then
				vim.notify("No saved atom macro")
				return
			end
			for _, step in ipairs(vim.g.atom_macro) do
				vim.api.nvim_feedkeys(vim.keycode(step.keys or step.lhs), step.keys and "n" or "m", false)
			end
			return
		elseif #atom_ring == 0 then
			vim.notify("No recorded actions")
			return
		end
		local parts = {}
		for i = math.max(1, #atom_ring - count + 1), #atom_ring do
			local atom = atom_ring[i]
			local field = atom.keys and "keys" or "lhs"
			parts[#parts + 1] = ("{%s=%q},"):format(field, vim.fn.keytrans(atom.keys or atom.lhs))
		end
		local command = (":lua vim.g.atom_macro = { %s }"):format(table.concat(parts, " "))
		vim.api.nvim_feedkeys(command .. vim.keycode("<C-f>"), "n", false)
	end)
end, { desc = "Replay atom macro; use a count to edit recent actions" })
