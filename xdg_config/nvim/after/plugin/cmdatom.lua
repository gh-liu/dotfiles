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
