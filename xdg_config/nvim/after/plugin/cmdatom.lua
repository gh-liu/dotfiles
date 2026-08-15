-- CmdAtom-driven enhancements.
-- See |CmdAtom| and the worked examples in |repeat.txt|.

-- ====================================================================
-- 1. Semantic Visual dot-repeat: "." in Visual mode re-executes the last
--    Visual operation (selection + operator) via its captured keysequence,
--    instead of a bare ":normal .". Falls back to ":normal ." (the old
--    behavior) when no replayable Visual atom is known.
-- ====================================================================
vim.api.nvim_create_autocmd("CmdAtom", {
	callback = function(ev)
		if ev.data.type == "visual" then
			local keys = ev.data.keys
			if keys ~= "" then
				vim.g.voperator = keys
			end
		elseif ev.data.changed then
			vim.g.voperator = nil -- the last change is no longer the Visual one
		end
	end,
})
vim.keymap.set("x", ".", function()
	-- CmdAtom is deferred: schedule the replay after any pending event,
	-- so `vim.g.voperator` is fresh. Leave Visual mode first: the captured
	-- keys are a Normal-mode sequence (e.g. "viwd") and must not be consumed
	-- while still in Visual mode.
	vim.schedule(function()
		if vim.g.voperator then
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
			vim.api.nvim_feedkeys(vim.g.voperator, "n", false) -- "n": already resolved
		else
			vim.cmd("normal .")
		end
	end)
end)

-- ====================================================================
-- 2. "." in operator-pending mode repeats the last motion, so "d.",
--    "y.", "c." operate on the repeated motion (motion-repeat in
--    |repeat.txt|: "3w", "fx", "/pat<CR>", ...). An expr mapping feeds
--    the captured keys straight into the operator's motion stream.
--    Note: expr is evaluated synchronously; vim.g.motion is one event-loop
--    tick stale at worst, which is below human typing latency.
-- ====================================================================
vim.api.nvim_create_autocmd("CmdAtom", {
	pattern = "motion",
	callback = function(ev)
		vim.g.motion = ev.data.keys
	end,
})
vim.keymap.set("o", ".", function()
	return vim.g.motion or ""
end, { expr = true })

-- ====================================================================
-- 3. Undo/redo change highlight: on `u`/`<C-r>` (or :undo/:redo/:earlier/
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
				vim.b[buf]._undodiff_last_change = { start_row, start_col, start_row, start_col + math.max(len, 1), dir }
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

--- Undo/redo atoms: keys u/<C-r> (command) or :undo/:redo/:earlier/:later (ex).
--- `keys` carries the full ex line for `:` atoms (cmd is always ":").
local is_undo_atom = function(d)
	if d.type == "command" then
		return d.cmd == "u" or d.cmd == "<C-R>" or d.cmd == "g-" or d.cmd == "g+"
	elseif d.type == "ex" then
		local k = d.keys or ""
		return k:match("^:undo") ~= nil or k:match("^:u\n") ~= nil or k:match("^:u%d") ~= nil
			or k:match("^:redo") ~= nil or k:match("^:earlier") ~= nil or k:match("^:later") ~= nil
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
