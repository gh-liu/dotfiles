" Wipe undo history.
"   :UndoWipe         clear current buffer's in-memory undo + delete its undofile
"   :UndoWipe ++all   delete every file under &undodir
" :h clear-undo  :h undofile()  :h persistent-undo
command! -nargs=? -bar -complete=customlist,s:UndoWipeComplete UndoWipe call s:UndoWipe(<q-args>)

function! s:UndoWipeComplete(a, c, p) abort
    return filter(['++all'], 'stridx(v:val, a:a) == 0')
endfunction

function! s:UndoWipe(arg) abort
    if a:arg ==# '++all'
        let l:dir = split(&undodir, ',')[0]
        let l:n = 0
        for l:f in glob(l:dir . '/*', 1, 1)
            let l:n += delete(l:f) == 0
        endfor
        echo printf('UndoWipe: removed %d file(s) under %s', l:n, l:dir)
        return
    endif

    let l:old = &l:undolevels
    setlocal undolevels=-1
    execute "normal! a \<BS>\<Esc>"
    let &l:undolevels = l:old

    let l:uf = undofile(expand('%:p'))
    call delete(l:uf)
    echo 'UndoWipe: ' . l:uf
endfunction
