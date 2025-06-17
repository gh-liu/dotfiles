" copy from tpope/vim-unimpaired

function! s:Map(...) abort
  let [mode, head, rhs; rest] = a:000
  let flags = get(rest, 0, '') . (rhs =~# '^<Plug>' ? '' : '<script>')
  let tail = ''
  let keys = get(g:, mode.'remap', {})
  if type(keys) == type({}) && !empty(keys)
    while !empty(head) && len(keys)
      if has_key(keys, head)
        let head = keys[head]
        if empty(head)
          let head = '<skip>'
        endif
        break
      endif
      let tail = matchstr(head, '<[^<>]*>$\|.$') . tail
      let head = substitute(head, '<[^<>]*>$\|.$', '', '')
    endwhile
  endif
  if head !=# '<skip>' && empty(maparg(head.tail, mode))
    return mode.'map ' . flags . ' ' . head.tail . ' ' . rhs
  endif
  return ''
endfunction

" Section: Diff

nnoremap <silent> <Plug>(unimpaired-context-previous) :<C-U>call <SID>Context(1)<CR>
nnoremap <silent> <Plug>(unimpaired-context-next)     :<C-U>call <SID>Context(0)<CR>
vnoremap <silent> <Plug>(unimpaired-context-previous) :<C-U>exe 'normal! gv'<Bar>call <SID>Context(1)<CR>
vnoremap <silent> <Plug>(unimpaired-context-next)     :<C-U>exe 'normal! gv'<Bar>call <SID>Context(0)<CR>
onoremap <silent> <Plug>(unimpaired-context-previous) :<C-U>call <SID>ContextMotion(1)<CR>
onoremap <silent> <Plug>(unimpaired-context-next)     :<C-U>call <SID>ContextMotion(0)<CR>

exe s:Map('n', '[n', '<Plug>(unimpaired-context-previous)')
exe s:Map('n', ']n', '<Plug>(unimpaired-context-next)')
exe s:Map('x', '[n', '<Plug>(unimpaired-context-previous)')
exe s:Map('x', ']n', '<Plug>(unimpaired-context-next)')
exe s:Map('o', '[n', '<Plug>(unimpaired-context-previous)')
exe s:Map('o', ']n', '<Plug>(unimpaired-context-next)')

nnoremap <silent> <Plug>unimpairedContextPrevious :<C-U>call <SID>Context(1)<CR>
nnoremap <silent> <Plug>unimpairedContextNext     :<C-U>call <SID>Context(0)<CR>
xnoremap <silent> <Plug>unimpairedContextPrevious :<C-U>exe 'normal! gv'<Bar>call <SID>Context(1)<CR>
xnoremap <silent> <Plug>unimpairedContextNext     :<C-U>exe 'normal! gv'<Bar>call <SID>Context(0)<CR>
onoremap <silent> <Plug>unimpairedContextPrevious :<C-U>call <SID>ContextMotion(1)<CR>
onoremap <silent> <Plug>unimpairedContextNext     :<C-U>call <SID>ContextMotion(0)<CR>

function! s:Context(reverse) abort
  call search('^\(@@ .* @@\|[<=>|]\{7}[<=>|]\@!\)', a:reverse ? 'bW' : 'W')
endfunction

function! s:ContextMotion(reverse) abort
  if a:reverse
    -
  endif
  call search('^@@ .* @@\|^diff \|^[<=>|]\{7}[<=>|]\@!', 'bWc')
  if getline('.') =~# '^diff '
    let end = search('^diff ', 'Wn') - 1
    if end < 0
      let end = line('$')
    endif
  elseif getline('.') =~# '^@@ '
    let end = search('^@@ .* @@\|^diff ', 'Wn') - 1
    if end < 0
      let end = line('$')
    endif
  elseif getline('.') =~# '^=\{7\}'
    +
    let end = search('^>\{7}>\@!', 'Wnc')
  elseif getline('.') =~# '^[<=>|]\{7\}'
    let end = search('^[<=>|]\{7}[<=>|]\@!', 'Wn') - 1
  else
    return
  endif
  if end > line('.')
    execute 'normal! V'.(end - line('.')).'j'
  elseif end == line('.')
    normal! V
  endif
endfunction
