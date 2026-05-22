vim.cmd([[
augroup liu.core
  autocmd!
  autocmd VimResized * wincmd = 
augroup END

augroup liu.focus
  autocmd!
  autocmd FocusGained *  if &buftype=='' | checktime | endif
  "automatically save all modified buffers without prompting for confirmation whenever focus is lost
  autocmd FocusLost * let s:confirm = &confirm | setglobal noconfirm | silent! wall | let &confirm = s:confirm
  autocmd FocusLost,BufHidden * if &buftype=='' && filereadable(expand('%:p')) | silent lockmarks update ++p | endif
augroup END

"augroup liu.mkview.folds
"  autocmd!
"  " Use numbered view 9 dedicated to fold info only, so it never conflicts
"  " with the unnumbered view (cursor/curdir/etc). Save/restore the global
"  " 'viewoptions' around mkview to limit what gets persisted to folds.
"  au BufWinLeave * if &buftype ==# '' && expand('%') !=# ''
"    \ | let s:save_vop = &viewoptions
"    \ | set viewoptions=folds
"    \ | silent! mkview 9
"    \ | let &viewoptions = s:save_vop
"    \ | endif
"  " Defer loadview to the next event loop tick via timer_start(0, ...).
"  " For foldmethod=expr (e.g. treesitter), the fold tree may not be ready
"  " right at BufWinEnter, so the per-line `sil! normal! zo` commands inside
"  " the view file would no-op. Deferring lets the fold structure settle
"  " before loadview runs, so manually opened folds are restored correctly.
"  "au BufWinEnter * if &buftype ==# '' && expand('%') !=# '' | call timer_start(0, {-> execute('silent! loadview 9')}) | endif
"  au BufWinEnter * if &buftype ==# '' && expand('%') !=# '' | silent! loadview 9 | endif
"augroup END
]])

local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

---@param group_name string
local liu_augroup = function(group_name)
	return augroup("liu/" .. group_name, { clear = true })
end

-- -- :h vim.hl.on_yank
-- augroups.highlighting_yank = {
-- 	highlighting_yank = {
-- 		event = { "TextYankPost" },
-- 		callback = function()
-- 			vim.hl.on_yank({
-- 				-- higroup = "Search",
-- 				timeout = vim.o.timeoutlen,
-- 				priority = vim.hl.priorities.user + 111,
-- 			})
-- 		end,
-- 	},
-- }

autocmd({ "TextYankPost", "TextPutPost" }, {
	desc = "highlight on operator",
	group = liu_augroup("hl_op"),
	callback = function(ev)
		local event = vim.v.event
		if event.regtype == "" or event.regname == "_" then
			return
		end
		local higroup
		-- if ev.event == "TextYankPost" then
		-- end
		if ev.event == "TextPutPost" then
			-- mini.operators "replace" uses temp register "x" → @diff.delta
			-- everything else (p/P, visual put, <C-r> paste) → @diff.plus
			higroup = event.regname == "x" and "@diff.delta" or "@diff.plus"
		end
		vim.hl.hl_op({
			higroup = higroup,
			timeout = vim.o.timeoutlen,
			priority = vim.hl.priorities.user + 111,
		})
	end,
})

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
	group = liu_augroup("snippet_stop"),
	callback = function()
		if vim.snippet.active() then
			vim.snippet.stop()
		end
	end,
})

-- vim.api.nvim_create_autocmd("BufWritePost", {
-- 	group = liu_augroup("trust_nvim_lua"),
-- 	pattern = { ".nvim.lua" },
-- 	callback = function(args)
-- 		vim.secure.trust({
-- 			action = "allow",
-- 			-- path = args.match,
-- 			bufnr = args.buf,
-- 		})
-- 		vim.api.nvim_echo({ { "trust ", "WarningMsg" }, { args.match } }, false, {})
-- 	end,
-- })

-- vim: foldmethod=marker
