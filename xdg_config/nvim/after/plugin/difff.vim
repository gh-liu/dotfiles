" ============================================================================
" difff.vim - Enhanced diff functionality
" ============================================================================
" Provides:
"   - Automatic fold management in diff mode
"   - Quick diff toggle and update mappings
"   - Diff anchor alignment using marks or visual selection

" ----------------------------------------------------------------------------
" Auto-disable folding in diff mode
" ----------------------------------------------------------------------------
augroup DiffFoldenable
  autocmd!
  autocmd OptionSet diff
        \ if v:option_new |
        \   let w:diff_foldenable = &foldenable |
        \   set nofoldenable |
        \ else |
        \   let &foldenable = get(w:, 'diff_foldenable', 1) |
        \ endif
augroup END

" ----------------------------------------------------------------------------
" Key mappings
" ----------------------------------------------------------------------------
" dyy: Toggle diff mode for all windows
nnoremap <silent> dyy :if &diff<CR>windo diffoff<CR>else<CR>windo diffthis<CR>endif<CR>
" dyu: Update diff
nnoremap <silent> dyu :diffupdate<CR>
" dyl: Reset diff anchors to default
nnoremap <silent> dyl :windo if &diff \| setlocal diffanchors& \| endif<bar>set diffopt-=anchor<bar>diffupdate<CR>
" dym: Set diff anchors using marks (a-z)
nnoremap <silent> dym :call <SID>DiffAnchorMark()<CR>
" dys: Set diff anchors using visual selection
xnoremap <silent> dys :<C-U>call <SID>DiffAnchorVisual()<CR>

" ----------------------------------------------------------------------------
" Functions
" ----------------------------------------------------------------------------

" Set diff anchors using marks (a-z) that exist in all diff windows
function! s:DiffAnchorMark() abort
  if !&diff
    echo "Not in diff mode"
    return
  endif

  let common_marks = []
  let is_first_window = 1

  " Collect marks from all diff windows
  windo if &diff
    \ | let marks = filter(range(97, 122), 'getpos("''" . nr2char(v:val))[1] > 0')
    \ | if is_first_window
    \ |   let common_marks = marks
    \ |   let is_first_window = 0
    \ | else
    \ |   let common_marks = filter(common_marks, 'index(marks, v:val) >= 0')
    \ | endif
    \ | endif

  if empty(common_marks)
    echo "No common marks found in diff windows"
    return
  endif

  " Use first and last common mark
  let start_mark = nr2char(common_marks[0])
  let end_mark = nr2char(common_marks[-1])

  " Set anchors using marks directly (no line numbers)
  let did_set = 0
  windo if &diff
    \ | let start_line = getpos("'" . start_mark)[1]
    \ | let end_line = getpos("'" . end_mark)[1]
    \ | if start_line > 0 && end_line > 0
    \ |   if start_mark ==# end_mark
    \ |     let &l:diffanchors = "'" . start_mark
    \ |   else
    \ |     let &l:diffanchors = "'" . start_mark .. ",'" .. end_mark
    \ |   endif
    \ |   let did_set += 1
    \ | endif
    \ | endif

  if did_set == 0
    echo "Invalid mark positions"
    return
  endif

  set diffopt+=anchor
  diffupdate
  echo printf("Diff anchors set: %d window(s)", did_set)
endfunction

" Set diff anchors using visual selection
function! s:DiffAnchorVisual() abort
  if !&diff
    echo "Not in diff mode"
    return
  endif

  " Use visual marks directly:
  " - first anchor at `'<`
  " - second anchor at `'>+1` so the split happens below selection
  let &l:diffanchors = "'<,'>+1"
  set diffopt+=anchor
  diffupdate
  echo "Diff anchors set: visual selection"
endfunction
