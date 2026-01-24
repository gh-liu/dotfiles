vim.cmd([[
augroup liu_autocmds_core
  autocmd!
  autocmd VimResized * wincmd = 
  autocmd FocusGained *  if &buftype=='' | checktime | endif
  "automatically save all modified buffers without prompting for confirmation whenever focus is lost
  autocmd FocusLost * let s:confirm = &confirm | setglobal noconfirm | silent! wall | let &confirm = s:confirm
  autocmd BufHidden,FocusLost * if &buftype=='' && filereadable(expand('%:p')) | silent lockmarks update ++p | endif
  "-- Don't auto-wrap comments and don't insert comment leader after hitting 'o'
  "-- If don't do this on `FileType`, this keeps reappearing due to being set in
  "-- filetype plugins.
  autocmd TermOpen * startinsert
augroup END
]])

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

api.nvim_create_autocmd({ "CursorHold" }, {
	desc = "stop snippet when in active",
	callback = function()
		if vim.snippet.active() then
			vim.snippet.stop()
		end
	end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = { ".nvim.lua" },
	callback = function(args)
		vim.secure.trust({
			action = "allow",
			-- path = args.match,
			bufnr = args.buf,
		})
		vim.api.nvim_echo({ { "trust ", "WarningMsg" }, { args.match } }, false, {})
	end,
})
--

-- vim: foldmethod=marker
