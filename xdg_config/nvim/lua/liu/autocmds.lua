local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

local general = augroup("UserGeneralSettings", { clear = true })

autocmd("TextYankPost", {
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({
			timeout = vim.o.updatetime,
			priority = vim.highlight.priorities.user + 1,
		})
	end,
	group = general,
	desc = "Highlight when yanking",
})

autocmd("FocusGained", {
	callback = function()
		-- normal buffer
		if vim.o.bt == "" then
			vim.cmd("checktime")
		end
	end,
	group = general,
	desc = "Update file when there are changes",
})

autocmd("VimResized", {
	group = general,
	command = "wincmd =",
	desc = "Equalize Splits",
})

autocmd("BufWritePre", {
	group = general,
	command = "%s/\\s\\+$//e",
	desc = "Trim Trailing",
})

autocmd("BufEnter", {
	callback = function()
		vim.opt.formatoptions:remove({ "c", "r", "o" })
	end,
	group = general,
	desc = "Disable New Line Comment",
})

autocmd({ "BufWinLeave", "BufLeave", "InsertLeave", "FocusLost" }, {
	callback = function()
		vim.cmd("silent! w")
	end,
	group = general,
	desc = "Auto Save when leaving insert mode, buffer or window",
})

autocmd("ModeChanged", {
	callback = function()
		local cmdtype = vim.fn.getcmdtype()
		if cmdtype == "/" or cmdtype == "?" then
			vim.opt.hlsearch = true
		else
			vim.opt.hlsearch = false
		end
	end,
	group = general,
	desc = "Highlighting matched words when searching",
})

-- :h last-position-jump
autocmd("BufReadPost", {
	callback = function()
		if vim.fn.line("'\"") > 1 and vim.fn.line("'\"") <= vim.fn.line("$") then
			vim.cmd('normal! g`"')
		end
	end,
	group = general,
	desc = "Go To The Last Cursor Position",
})

autocmd("BufWinEnter", {
	group = augroup("UserOpenHelpInTab", {}),
	pattern = { "*.txt" },
	callback = function()
		if vim.o.filetype == "help" then
			vim.cmd.wincmd("T")
		end
	end,
	desc = "Open help file in a new table",
})
