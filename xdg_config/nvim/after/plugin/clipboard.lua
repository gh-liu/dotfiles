if false then
	return
end

-- disable in TMUX
if os.getenv("TMUX") then
	return
end

-- local function osc52_copy(text)
-- 	local osc = string.format("%s]52;c;%s%s", string.char(0x1b), vim.base64.encode(text), string.char(0x07))
-- 	io.stderr:write(osc)
-- end

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function(ev)
		local text = vim.fn.getreg(vim.v.event.regname)
		require("vim.clipboard.osc52").copy({ text })
		-- osc52_copy(text)
	end,
})
