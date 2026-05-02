vim.cmd([[
nnoremap `\ <cmd> vsplit <bar> term <cr>
nnoremap `- <cmd> bo split  <bar> term <cr>

augroup liu.term
  autocmd!
  autocmd TermOpen * startinsert
  "autocmd TermOpen * setlocal stl=%f
  autocmd TermOpen * setlocal statusline=%{b:term_title}
  "autocmd TermOpen * noremap <buffer> dq <cmd>bd!<cr>
augroup END

tnoremap jk <C-\><C-n>
tnoremap <esc> <C-\><C-n>
"tnoremap <C-g> <C-\><C-n>
"tnoremap <C-w> <C-\><C-n><C-w>
tnoremap <C-p> <Up>
tnoremap <C-n> <Down>
tnoremap <C-f> <Right>
tnoremap <C-b> <Left>
tnoremap <C-a> <Home>
tnoremap <C-e> <End>
tnoremap <C-q> <C-\><C-n>:quit<cr>
]])

local aug_term = vim.api.nvim_create_augroup("liu.term.osc", { clear = true })
vim.api.nvim_create_autocmd({ "TermRequest" }, {
	group = aug_term,
	desc = "Handles OSC 7 dir change requests",
	callback = function(ev)
		local val, n = string.gsub(ev.data.sequence, "\027]7;file://[^/]*", "")
		if n > 0 then
			-- OSC 7: dir-change
			local dir = val
			if vim.fn.isdirectory(dir) == 0 then
				vim.notify("invalid dir: " .. dir)
				return
			end
			vim.b[ev.buf].osc7_dir = dir
			if vim.api.nvim_get_current_buf() == ev.buf then
				vim.cmd.lcd(dir)
			end
		end
	end,
})

local ns_term_prompt = vim.api.nvim_create_namespace("liu.term.prompt")
local aug_term_prompt = vim.api.nvim_create_augroup("liu.term.prompt", { clear = true })
vim.api.nvim_create_autocmd("TermOpen", { command = "setlocal signcolumn=auto" })
vim.api.nvim_create_autocmd({ "TermRequest" }, {
	group = aug_term_prompt,
	callback = function(ev)
		if string.match(ev.data.sequence, "^\027]133;A") then
			-- OSC 133: shell-prompt
			local lnum = ev.data.cursor[1] ---@type integer
			vim.api.nvim_buf_set_extmark(ev.buf, ns_term_prompt, lnum - 1, 0, {
				sign_text = "∙",
				sign_hl_group = "SpecialChar",
			})
		end
	end,
})
