if false then
	return
end

-- disable in TMUX
if os.getenv("TMUX") then
	return
end

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function(ev)
		local text = vim.fn.getreg(vim.v.event.regname)
		require("vim.ui.clipboard.osc52").copy({ text })
	end,
})
