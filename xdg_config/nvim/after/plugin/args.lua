vim.keymap.set("n", "zY", function()
	local bufname = vim.iter(vim.fn.argv()):find(function(arg)
		return vim.fn.bufname() == arg
	end)
	if not bufname then
		vim.cmd([[argadd % | argdedupe]])
	else
		vim.cmd([[argdelete %]])
	end
	vim.cmd.redrawstatus()
end)
