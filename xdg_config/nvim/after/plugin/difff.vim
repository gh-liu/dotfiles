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
nnoremap <silent> dyy :if &diff<bar>windo diffoff<bar>else<bar>windo diffthis<bar>endif<CR>
" dyu: Update diff
nnoremap <silent> dyu :diffupdate<CR>
" dyl: Reset diff anchors to default
nnoremap <silent> dyl :setlocal diffanchors=&<bar>set diffopt-=anchor<bar>diffupdate<CR>
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
    \ let marks = filter(range(97, 122), 'getpos("''" . nr2char(v:val))[1] > 0')
    \ | if is_first_window
    \ |   let common_marks = marks
    \ |   let is_first_window = 0
    \ | else
    \ |   let common_marks = filter(common_marks, 'index(marks, v:val) >= 0')
    \ | endif
    \ endif

  if empty(common_marks)
    echo "No common marks found in diff windows"
    return
  endif

  " Use first and last common mark
  let start_mark = common_marks[0]
  let end_mark = common_marks[-1]
  let start_line = getpos("'" . nr2char(start_mark))[1]
  let end_line = getpos("'" . nr2char(end_mark))[1]

  if start_line == 0 || end_line == 0
    echo "Invalid mark positions"
    return
  endif

  let &l:diffanchors = start_line .. ',' .. end_line
  set diffopt+=anchor
  diffupdate
  echo printf("Diff anchors set: %d-%d", start_line, end_line)
endfunction

" Set diff anchors using visual selection
function! s:DiffAnchorVisual() abort
  if !&diff
    echo "Not in diff mode"
    return
  endif

  let start_line = line("'<")
  let end_line = line("'>")

  " Ensure start <= end
  if start_line > end_line
    let [start_line, end_line] = [end_line, start_line]
  endif

  if start_line == 0 || end_line == 0
    echo "Invalid selection"
    return
  endif

  let &l:diffanchors = start_line .. ',' .. end_line
  set diffopt+=anchor
  diffupdate
  echo printf("Diff anchors set: %d-%d", start_line, end_line)
endfunction
