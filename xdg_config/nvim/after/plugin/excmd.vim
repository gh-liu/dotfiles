func! ReadExCommandOutput(newbuf, cmd) abort
  redir => l:message
  silent! execute a:cmd
  redir END
  if a:newbuf | wincmd n | endif
  silent put=l:message
endf

command! -nargs=+ -bang -complete=command R call ReadExCommandOutput(<bang>0, <q-args>)

func! CopyMessageOutput() abort
  redir => l:temp
  execute "message"
  redir END

  call setreg('+', l:temp)
endf

command! -nargs=0 -bang CpMessage call CopyMessageOutput()
