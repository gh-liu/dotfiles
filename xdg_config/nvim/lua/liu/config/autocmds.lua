local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

---@param group_name string
local liu_augroup = function(group_name)
	return augroup("liu/" .. group_name, { clear = true })
end

-- last location {{{1
autocmd("BufReadPost", {
	desc = "Go to the last location when opening a buffer",
	group = liu_augroup("last_location"),
	callback = function(args)
		-- local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		-- local line_count = vim.api.nvim_buf_line_count(args.buf)
		-- if mark[1] > 0 and mark[1] <= line_count then
		-- 	vim.cmd('normal! g`"zz')
		-- end

		if vim.bo.buftype ~= "" or vim.b.disable_restore_cursor then
			return
		end
		-- Stop if line is already specified (like during start with `nvim file +num`)
		local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
		if cursor_line > 1 then
			return
		end
		-- Stop if can't restore proper line for some reason
		local mark_line = vim.api.nvim_buf_get_mark(0, [["]])[1]
		local n_lines = vim.api.nvim_buf_line_count(0)
		if not (1 <= mark_line and mark_line <= n_lines) then
			return
		end
		-- Restore cursor and
		vim.cmd([[normal! g`"]])
		-- Open just enough folds
		vim.cmd([[normal! zv]])
		-- Center window
		vim.cmd("normal! zz")
	end,
})
-- }}}

autocmd("VimResized", {
	desc = "Equalize Splits",
	group = liu_augroup("resize_splits"),
	command = "wincmd =",
})

autocmd({ "FocusGained" }, {
	desc = "Update file when there are changes",
	group = liu_augroup("checktime"),
	callback = function()
		-- normal buffer
		if vim.o.bt == "" then
			vim.cmd("checktime")
		end
	end,
})

autocmd({ "BufWritePre" }, {
	group = liu_augroup("auto_create_dir"),
	callback = function(event)
		if event.match:match("^%w%w+://") then
			return
		end
		---@diagnostic disable-next-line: undefined-field
		local file = vim.uv.fs_realpath(event.match) or event.match
		vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
	end,
})

autocmd("BufHidden", {
	desc = "Delete [No Name] buffers",
	group = liu_augroup("delete_noname_buffers"),
	callback = function(data)
		if data.file == "" and vim.bo[data.buf].buftype == "" and not vim.bo[data.buf].modified then
			vim.schedule(function()
				pcall(api.nvim_buf_delete, data.buf, {})
			end)
		end
	end,
})

local auto_root_dirs = {
	".git",
	-- "Makefile",
	-- "go.mod", -- go
	-- "Cargo.toml", -- rust
	-- "build.zig.zon", -- zig
	-- "pyproject.toml", -- python
	".nvim.lua",
	".projections.json",
	".nvimrc", -- :h exrc
	".nvim.lua", -- :h exrc
	".projections.json", -- :h projectionist-setup
}
autocmd("BufEnter", {
	group = liu_augroup("setup_auto_root"),
	callback = function(data)
		-- vim.o.autochdir = false
		local root = vim.fs.root(data.buf, auto_root_dirs)
		if root == nil then
			return
		end
		vim.fn.chdir(root)
	end,
	desc = "Find root and change current directory",
	once = true,
})

-- autocmd("BufWinEnter", {
-- 	desc = "Open help file in right split",
-- 	group = liu_augroup("open_help_in_right_split"),
-- 	pattern = { "*.txt" },
-- 	callback = function(ev)
-- 		if vim.o.filetype == "help" then
-- 			local winnr = vim.fn.winnr("#")
-- 			local bufnr = vim.fn.winbufnr(winnr)
-- 			if vim.bo[bufnr].ft ~= "qf" then
-- 				vim.cmd.wincmd("L")
-- 			end
-- 		end
-- 	end,
-- })

-- options {{{1
autocmd("CmdwinEnter", {
	desc = "cmdwin option setup",
	group = liu_augroup("cmdwin_enter"),
	pattern = "*",
	callback = function()
		vim.wo.foldcolumn = "0"
		vim.wo.number = false
		vim.wo.relativenumber = false
		vim.wo.signcolumn = "no"
	end,
})

local toggle_cursorline = liu_augroup("toggle_cursorline")
autocmd({ "InsertLeave" }, {
	desc = "set cursorline",
	group = toggle_cursorline,
	command = "set cursorline",
})
autocmd({ "InsertEnter" }, {
	desc = "set nocursorline",
	group = toggle_cursorline,
	command = "set nocursorline",
})

local toggle_colorcolumn = liu_augroup("toggle_colorcolumn")
autocmd({ "InsertLeave" }, {
	desc = "unset colorcolumn",
	group = toggle_colorcolumn,
	command = "set colorcolumn=",
})
autocmd({ "InsertEnter" }, {
	desc = "set colorcolumn",
	group = toggle_colorcolumn,
	command = "set colorcolumn=80,120",
})

autocmd("FileType", {
	group = liu_augroup("formatoptions"),
	callback = function()
		-- Don't auto-wrap comments and don't insert comment leader after hitting 'o'
		-- If don't do this on `FileType`, this keeps reappearing due to being set in
		-- filetype plugins.
		vim.cmd("setlocal formatoptions-=c formatoptions-=o")
	end,
	desc = [[Ensure proper 'formatoptions']],
})

-- autocmd("ModeChanged", {
-- 	desc = "Highlighting matched words when searching",
-- 	group = liu_augroup("switch_highlight_when_searching"),
-- 	pattern = { "*:c", "c:*" },
-- 	callback = function(ev)
-- 		local cmdtype = vim.fn.getcmdtype()
-- 		if cmdtype == "/" or cmdtype == "?" then
-- 			vim.o.hlsearch = true
-- 		else
-- 			vim.o.hlsearch = false
-- 		end
-- 	end,
-- })

vim.cmd("packadd nohlsearch")

-- api.nvim_create_autocmd("InsertEnter", {
-- 	callback = vim.schedule_wrap(function()
-- 		vim.cmd.nohlsearch()
-- 	end),
-- })
-- }}}

local term_startinsert = liu_augroup("term_insert")
api.nvim_create_autocmd({ "TermOpen" }, {
	group = term_startinsert,
	command = "startinsert",
})
-- api.nvim_create_autocmd({ "BufEnter" }, {
-- 	pattern = "term://*",
-- 	group = term_startinsert,
-- 	command = "startinsert",
-- })

api.nvim_create_autocmd({ "CursorHold" }, {
	desc = "stop snippet when in active",
	callback = function()
		if vim.snippet.active() then
			vim.snippet.stop()
		end
	end,
})

-- maps {{{
local wrap_maps = liu_augroup("wrap_maps")
autocmd("WinEnter", {
	group = wrap_maps,
	callback = function(ev)
		if vim.wo[0].wrap then
			local buffer = ev.buf
			vim.keymap.set("n", "j", "gj", { buffer = buffer })
			vim.keymap.set("n", "k", "gk", { buffer = buffer })
		else
		end
	end,
})
autocmd("OptionSet", {
	desc = "OptionSetWrap",
	group = wrap_maps,
	pattern = "wrap",
	callback = function(ev)
		local buffer = ev.buf
		if vim.v.option_new then
			vim.keymap.set("n", "j", "gj", { buffer = buffer })
			vim.keymap.set("n", "k", "gk", { buffer = buffer })
		else
			pcall(vim.keymap.del, "n", "j", { buffer = buffer })
			pcall(vim.keymap.del, "n", "k", { buffer = buffer })
		end
	end,
})
-- }}}
vim.cmd([[  
autocmd BufHidden,FocusLost * if &buftype=='' && filereadable(expand('%:p')) | silent lockmarks update ++p | endif

"automatically save all modified buffers without prompting for confirmation whenever focus is lost
autocmd FocusLost * let s:confirm = &confirm | setglobal noconfirm | silent! wall | let &confirm = s:confirm
]])

-- vim: foldmethod=marker
