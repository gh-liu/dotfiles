" direction: 1=forward, -1=backward
function! s:Jump(direction, map) abort
    let jumpcmdchr = a:direction > 0 ? "\<C-o>" : "\<C-i>"
    let [list, pos] = getjumplist()
    if jumpcmdchr ==# "\<C-O>"
        let list = reverse(list)
        let pos = len(list) - 1 - pos
    endif
    let list = map(list, a:map)
    let cnt = index(list, 1, max([pos, 0])) - pos
    if cnt > 0
        execute "normal! ".cnt.jumpcmdchr
    endif
endfunction

" Jump entire buffers in jumplist
nnoremap g<C-i> <cmd>call <SID>Jump(-1, 'v:val.bufnr != '.bufnr('%'))<CR>
nnoremap g<C-o> <cmd>call <SID>Jump(1, 'v:val.bufnr != '.bufnr('%'))<CR>

