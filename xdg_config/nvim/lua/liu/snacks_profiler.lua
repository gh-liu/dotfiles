if vim.env.PROF then
	local snacks = vim.fn.stdpath("data") .. "/lazy/snacks.nvim"
	vim.opt.rtp:append(snacks)

	require("snacks.profiler").startup({
		startup = {
			-- stop profiler on this event. Defaults to `VimEnter`
			event = "VimEnter",
			-- event = "UIEnter",
			-- event = "VeryLazy",
		},
	})
end

vim.keymap.set("n", "gzp", function()
	local profiler = require("snacks.profiler")
	profiler.toggle()
	print("snacks profiler " .. (profiler.running() and "is running." or "stoped."))
end)
