vim.api.nvim_create_autocmd("User", {
	pattern = "MiniFilesExplorerOpen",
	callback = function()
		local MiniFiles = require("mini.files")
		if not MiniFiles then
			return
		end
		MiniFiles.set_bookmark("c", vim.fn.stdpath("config"), { desc = "Config" })
	end,
})
