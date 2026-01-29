command! -nargs=+ -bang -complete=command R if !<bang>0 | wincmd n | endif
    \ | call execute(printf("put=execute('%s')", substitute(escape(<q-args>, '"'), "'", "''", 'g')))

" execute last command and insert output into current buffer
inoremap <c-r>R <c-o>:<up><home>R! <cr>


command! -nargs=0 EscapeSpecial call s:EscapeSpecial()
function! s:EscapeSpecial()
    execute printf('%%substitute/%s/%s/ge', "\\\\n", "\\r")
    execute printf('%%substitute/%s/%s/ge', "\\\\r", "\\r")
    execute printf('%%substitute/%s/%s/ge', "\\\\t", "\\t")
endfunction

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

command! -nargs=0 -range Swap call s:Swap(<line1>, <line2>)
function! s:Swap(line1, line2)
    let w1 = getreg("1")
    let w2 = getreg("2")
    if w1 == "" || w2 == ""
        echohl WarningMsg
        echo "Need @1 and @2"
        echohl None
        return
    endif
    let w1_esc = escape(w1, '\/&')
    let w2_esc = escape(w2, '\/&')
    execute printf("%d,%ds/%s/%s/g", a:line1, a:line2, w2_esc, w1_esc)
endfunction

" vim: foldmethod=marker
