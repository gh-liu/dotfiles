" Global singleton :shell terminal toggler.
" <C-s>  Jump between :shell and the previous window; create one on first use.

" Jump back to the previous window if currently inside :shell.
" Returns v:true when handled.
func! s:JumpBack(b) abort
  if bufnr('%') != a:b
    return v:false
  endif
  if !win_gotoid(g:term_shell.prevwid)
    wincmd p
  endif
  return v:true
endfunc

" Jump to an existing :shell buffer; open a new tab if not displayed.
" Returns v:true when handled.
func! s:JumpTo(b) abort
  if !bufexists(a:b)
    return v:false
  endif
  let ws = win_findbuf(a:b)
  if !empty(ws)
    call win_gotoid(ws[0])
  else
    tab split
    exe 'buffer' a:b
  endif
  return v:true
endfunc

" Create a new :shell terminal in a new tab.
" Returns v:true (always creates).
func! s:Create() abort
  tab split
  terminal
  setlocal scrollback=-1 nobuflisted
  setlocal statusline=%f
  file :shell
  bwipeout! #
  tnoremap <buffer> <C-s> <C-\><C-n><cmd>call <SID>CtrlS()<CR>
  return v:true
endfunc

func! s:CtrlS() abort
  let g:term_shell = get(g:, 'term_shell', { 'prevwid': win_getid() })
  let b = bufnr(':shell')

  if s:JumpBack(b)
    return
  endif

  let g:term_shell.prevwid = win_getid()

  if s:JumpTo(b)
    return
  endif

  call s:Create()
endfunc

nnoremap <C-s> <cmd>call <SID>CtrlS()<CR>
