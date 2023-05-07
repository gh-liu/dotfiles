local function setup_cedit()
	if vim.fn.bufname() == "[Command Line]" then
		-- easy exit
		vim.keymap.set("n", "<c-o>", "G<cr>", { buffer = 0 })
	end
end

setup_cedit()
