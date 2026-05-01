command! -nargs=+ -bang -complete=command R if !<bang>0 | wincmd n | endif
    \ | call execute(printf("put=execute('%s')", substitute(escape(<q-args>, '"'), "'", "''", 'g')))

" execute last command and insert output into current buffer
inoremap <c-r>R <c-o>:<up><home>R! <cr>

" :h modeline
command! -nargs=0 AddModeline call s:AddModeline()
function! s:AddModeline()
    let options = []
    call add(options, "filetype=" . &filetype)
    call add(options, "tabstop=" . &tabstop)
    call add(options, "shiftwidth=" . &shiftwidth)
    call add(options, (&expandtab ? "" : "no") . "expandtab")
    call add(options, (&autoindent ? "" : "no") . "autoindent")
    let modeline = "vim: set " . join(options, " ") . " :"
    let idx = stridx(&commentstring, '%s')
    if idx != -1
        let before = strpart(&commentstring, 0, idx)
        let after = strpart(&commentstring, idx + 2)
        let modeline = before . modeline . after
    else
        let modeline = &commentstring . modeline
    endif
    call append(line('$'), modeline)
endfunction

" :h usr_29.txt
"
" https://ctags.io
" https://github.com/universal-ctags/ctags
"
" see the `--list-languages` and `--list-kinds` options.
command! -nargs=0 Tags call s:Tags()
function! s:Tags()
    let excludes = [".git", ".svn", ".hg"]
    let exclude_str = join(map(copy(excludes), {_, v -> "--exclude=" . v}), " ")
    execute "!ctags " . exclude_str . " --tag-relative=yes -R *"
endfunction

" vim: foldmethod=marker
