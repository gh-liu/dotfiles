augroup ftDetect
    au!
    au BufEnter,BufRead,BufNewFile go.mod call s:gomod()
    au BufEnter,BufRead,BufNewFile go.sum set filetype=gosum
    au BufEnter,BufRead,BufNewFile go.work set filetype=gowork

    au BufEnter,BufRead,BufNewFile *.gotmpl set filetype=gotmpl

    au BufEnter,BufRead,BufNewFile *.proto set filetype=proto

    au TermOpen term://*  set filetype=term
augroup END


" remove the autocommands for modsim3, and lprolog files so that their
" highlight groups, syntax, etc. will not be loaded. *.MOD is included, so
" that on case insensitive file systems the module2 autocmds will not be
" executed.
au! BufRead,BufNewFile *.mod,*.MOD

" Set the filetype if the first non-comment and non-blank line starts with
" 'module <path>'.
fun! s:gomod()
  for l:i in range(1, line('$'))
    let l:l = getline(l:i)
    if l:l ==# '' || l:l[:1] ==# '//'
      continue
    endif

    if l:l =~# '^module .\+'
      setfiletype gomod
    endif

    break
  endfor
endfun