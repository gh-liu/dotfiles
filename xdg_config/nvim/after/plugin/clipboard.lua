vim.o.clipboard = "unnamedplus"
if true then
	return
end

local function defer_write(content)
	local content = vim.fn.getreg('"')
	if content ~= "" then
		vim.fn.setreg("+", content)
	end
end
local function defer_read()
	local content = vim.fn.getreg("+")
	if content == "" then
		return nil
	end
	vim.fn.setreg('"', content)
end

local defer_sync_group = vim.api.nvim_create_augroup("UserDeferClipboardSync", { clear = true })
vim.api.nvim_create_autocmd({
	"FocusLost",
	"CmdlineEnter",
}, {
	group = defer_sync_group,
	callback = defer_write,
})
vim.api.nvim_create_autocmd("FocusGained", {
	group = defer_sync_group,
	callback = defer_read,
})
