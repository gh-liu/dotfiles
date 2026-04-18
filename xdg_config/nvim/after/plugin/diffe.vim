" ============================================================================
" difff.vim - Enhanced diff functionality
" ============================================================================
" Provides:
"   - Quick diff toggle and update mappings
"   - Diff anchor: dyv (pattern/visual), dym{mark}, dya (toggle), dyl (clear)

" ----------------------------------------------------------------------------
" Key mappings
" ----------------------------------------------------------------------------
" dyy: Toggle diff mode for all windows
nnoremap <silent> dyy :if &diff<CR>windo diffoff<CR>else<CR>windo diffthis<CR>endif<CR>
" dyu: Update diff
nnoremap <silent> dyu :diffupdate<CR>

" dya: Toggle anchor on/off
nnoremap <silent> dya :call <SID>DiffAnchorToggle()<CR>
" dyl: Clear all anchors
nnoremap <silent> dyl :call <SID>DiffAnchorClear()<CR>
" dyv (normal): Append current line as pattern anchor
nnoremap <silent> dyv :call <SID>DiffAnchorPattern()<CR>
" dyv (visual): Append selection as anchor
xnoremap <silent> dyv :<C-U>call <SID>DiffAnchorVisual()<CR>
" dym{a-z}: Append mark as anchor
nnoremap <silent> dym :call <SID>DiffAnchorMark()<CR>

" ----------------------------------------------------------------------------
" Functions
" ----------------------------------------------------------------------------

" Append current line text as pattern anchor (global diffanchors)
function! s:DiffAnchorPattern() abort
  if !&diff
    echo "Not in diff mode"
    return
  endif
  let line = getline('.')
  if line =~# '^\s*$'
    echo "Cannot anchor on blank line"
    return
  endif
  " Escape special characters for pattern
  let pattern = escape(line, '/\.*[]^$~')
  let anchor = '1/' .. pattern .. '/'
  call s:AppendAnchor(anchor, 0)
endfunction

" Append visual selection as anchor (local diffanchors)
function! s:DiffAnchorVisual() abort
  if !&diff
    echo "Not in diff mode"
    return
  endif
  call s:AppendAnchor("'<,'>+1", 1)
endfunction

" Read a mark char and append as anchor (global diffanchors)
function! s:DiffAnchorMark() abort
  if !&diff
    echo "Not in diff mode"
    return
  endif
  echo "Mark: "
  let c = nr2char(getchar())
  redraw
  if c !~# '[a-z]'
    echo "Invalid mark: " .. c
    return
  endif
  call s:AppendAnchor("'" .. c, 0)
endfunction

" Toggle diffopt anchor flag
function! s:DiffAnchorToggle() abort
  if !&diff
    echo "Not in diff mode"
    return
  endif
  if &diffopt =~# 'anchor'
    set diffopt-=anchor
    echo "Diff anchor: OFF"
  else
    set diffopt+=anchor
    echo "Diff anchor: ON"
  endif
  diffupdate
endfunction

" Clear all anchors and disable
function! s:DiffAnchorClear() abort
  windo if &diff | setlocal diffanchors& | endif
  set diffopt-=anchor
  diffupdate
  echo "Diff anchors cleared"
endfunction

" Append an anchor address. If local=1, use setlocal; otherwise set globally.
function! s:AppendAnchor(addr, local) abort
  if a:local
    let cur = &l:diffanchors
    let &l:diffanchors = (cur !=# '' ? cur .. ',' : '') .. a:addr
  else
    let cur = &diffanchors
    let &diffanchors = (cur !=# '' ? cur .. ',' : '') .. a:addr
  endif
  set diffopt+=anchor
  diffupdate
  echo "Anchor added: " .. a:addr
endfunction
