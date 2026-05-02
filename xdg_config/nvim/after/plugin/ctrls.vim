" Global singleton :shell terminal toggler.
" <C-s>      Jump between :shell and the previous window (new tab on first use).
" [N]<C-s>   Open :shell as a horizontal split N lines high in the current tab.

" Open a new window for :shell. cnt==0 -> new tab; otherwise full-width
" N-line split anchored to the bottom of the screen.
func! s:OpenWin(cnt) abort
  exe (a:cnt == 0 ? 'tab split' : 'botright ' . a:cnt . 'split')
endfunc

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

" Jump to an existing :shell buffer; open a new window if not displayed.
" Returns v:true when handled.
func! s:JumpTo(b, cnt) abort
  if !bufexists(a:b)
    return v:false
  endif
  let ws = win_findbuf(a:b)
  if !empty(ws) && a:cnt == 0
    call win_gotoid(ws[0])
  else
    call s:OpenWin(a:cnt)
    exe 'buffer' a:b
  endif
  return v:true
endfunc

" Create a new :shell terminal.
func! s:Create(cnt) abort
  call s:OpenWin(a:cnt)
  terminal
  setlocal scrollback=-1 nobuflisted
  setlocal statusline=%f
  file :shell
  bwipeout! #
  tnoremap <buffer> <C-s> <C-\><C-n><cmd>call <SID>CtrlS(0)<CR>
  return v:true
endfunc

func! s:CtrlS(cnt) abort
  let g:term_shell = get(g:, 'term_shell', { 'prevwid': win_getid() })
  let b = bufnr(':shell')

  if s:JumpBack(b)
    return
  endif

  let g:term_shell.prevwid = win_getid()

  if s:JumpTo(b, a:cnt)
    return
  endif

  call s:Create(a:cnt)
endfunc

nnoremap <C-s> <cmd>call <SID>CtrlS(v:count)<CR>
