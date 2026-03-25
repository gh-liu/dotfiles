" fustash.vim - Stash workflow for vim-fugitive

if exists('g:loaded_fustash') || !exists('*FugitiveGitDir')
  finish
endif
let g:loaded_fustash = 1

let s:stash_list_cmd = "--paginate stash list '--pretty=format:%h %as %<(10)%gd %<(76,trunc)%s'"

function! s:OpenStashList() abort
  execute 'G ' . s:stash_list_cmd
endfunction

function! s:GetStashIndex() abort
  let line = getline('.')
  return matchstr(line, 'stash@{\d\+}')
endfunction

function! s:RefreshStashPager() abort
  execute '0G ' . s:stash_list_cmd
endfunction

function! s:OpStash(cmd) abort
  let idx = s:GetStashIndex()
  if empty(idx)
    return
  endif
  execute 'Git stash ' . a:cmd . ' --quiet ' . idx
  call s:RefreshStashPager()
endfunction

function! s:SetupFugitiveBuffer() abort
  " czl: list, czm: save (in fugitive buffer)
  nnoremap <silent><buffer> czl :<C-U>call <SID>OpenStashList()<CR>
  nnoremap <nowait><buffer> czm :<C-U>G stash save<Space>
endfunction

function! s:SetupFugitivePager() abort
  " czd: drop, czO: pop, czo: pop --index (in FugitivePager)
  setlocal bufhidden=delete
  nnoremap <silent><buffer> czd :<C-U>call <SID>OpStash('drop')<CR>
  nnoremap <silent><buffer> czO :<C-U>call <SID>OpStash('pop')<CR>
  nnoremap <silent><buffer> czo :<C-U>call <SID>OpStash('pop --index')<CR>
endfunction

function! s:GStashList() abort
  let dir = FugitiveGitDir()
  let result = fugitive#Execute(dir, 'stash', 'list', '--pretty=format:%H %<(10)%gd %<(76,trunc)%s')
  if result.exit_status != 0
    return
  endif

  let qfitems = []
  for line in result.stdout
    if empty(line)
      continue
    endif
    let parts = matchlist(line, '^\(\x\+\)\s\+\(\S\+\)\s\+\(.*\)$')
    if empty(parts)
      continue
    endif
    call add(qfitems, {
          \ 'module': parts[1],
          \ 'filename': printf('fugitive://%s//%s', dir, parts[1]),
          \ 'text': parts[3],
          \ })
  endfor

  if !empty(qfitems)
    call setqflist(qfitems)
    copen
  endif
endfunction

augroup Fustash
  autocmd!
  autocmd FileType fugitive call <SID>SetupFugitiveBuffer()
  autocmd User FugitivePager call <SID>SetupFugitivePager()
augroup END

command! -nargs=0 GStashList call <SID>GStashList()
