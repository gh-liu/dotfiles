if true then
	local autocmd = vim.api.nvim_create_autocmd
	local augroup = vim.api.nvim_create_augroup

	local yankg = augroup("UserYankSetting", { clear = true })
	local cursor_pos
	autocmd({ "VimEnter", "CursorMoved" }, {
		pattern = "*",
		callback = function()
			cursor_pos = vim.fn.getpos(".")
		end,
		group = yankg,
		desc = "Remember Current Cursor Position",
	})
	autocmd("TextYankPost", {
		pattern = "*",
		callback = function()
			if vim.v.event and vim.v.event.operator == "y" then
				vim.fn.setpos(".", cursor_pos)
			end
		end,
		group = yankg,
		desc = "Keep Cursor Position on Yank",
	})
end

-- https://vim.fandom.com/wiki/Copy_search_matches#Copy_matches
vim.cmd([[
function! CopyAllMatches(reg)
  let hits = []

  %s//\=len(add(hits, submatch(0))) ? submatch(0) : ''/gne

  let reg = empty(a:reg) ? '+' : a:reg
  execute 'let @'.reg.' = join(hits, "\n") . "\n"'
endfunction

command! -register CopyMatches call CopyAllMatches(<q-reg>)
]])
