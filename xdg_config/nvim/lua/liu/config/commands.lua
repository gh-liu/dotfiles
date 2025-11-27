local api = vim.api
local create_command = vim.api.nvim_create_user_command

vim.cmd([[
command! -nargs=+ -bang -complete=command R if !<bang>0 | wincmd n | endif
    \ | call execute(printf("put=execute('%s')", substitute(escape(<q-args>, '"'), "'", "''", 'g')))

" execute last command and insert output into current buffer
inoremap <c-r>R <c-o>:<up><home>R! <cr>


command! -nargs=0 EscapeSpecial call s:EscapeSpecial()
function! s:EscapeSpecial()
    execute printf('%%substitute/%s/%s/ge', "\\\\n", "\\r")
    execute printf('%%substitute/%s/%s/ge', "\\\\t", "\\t")
endfunction
]])

-- :h modeline
create_command("AddModeline", function()
	local options = {
		"filetype=" .. vim.bo.ft,
		"tabstop=" .. vim.bo.ts,
		"shiftwidth=" .. vim.bo.sw,
		(vim.bo.expandtab and "" or "no") .. "expandtab",
		(vim.bo.autoindent and "" or "no") .. "autoindent",
	}
	local modeline = string.format("vim: set %s :", vim.iter(options):join(" "))
	vim.api.nvim_buf_set_lines(0, -1, -1, false, { string.format(vim.bo.commentstring, modeline) })
end, { nargs = 0 })

-- :h usr_29.txt
--
-- https://ctags.io
-- https://github.com/universal-ctags/ctags
--
-- see the `--list-languages` and `--list-kinds` options.
local ctags_exclude = { ".git", ".svn", ".hg" }
local ctags_exclude_str = vim.iter(ctags_exclude)
	:map(function(item)
		return "--exclude=" .. item
	end)
	:join(" ")
create_command("Tags", string.format("!ctags %s --tag-relative=yes -R *", ctags_exclude_str), { nargs = 0 })

-- vim: foldmethod=marker
