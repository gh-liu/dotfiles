function s:is_qfwin_opened() abort
  return getqflist({'winid': 0}).winid > 0
endfunction

function s:current_qfid_equal(qfid) abort
  return getqflist({'id': 0}).id == a:qfid
endfunction

function s:qf_idx(qfid) abort
  return getqflist({'id': a:qfid, 'idx': 0}).idx
endfunction

function s:get_diffbuf(buf) abort
  return getbufvar(a:buf, "diff_buf")
endfunction

function s:is_current_diffbuf_showed(buf) abort
  let bufnrs = tabpagebuflist()
  let diff_buf = s:get_diffbuf(a:buf)
  if diff_buf > 0 && bufloaded(diff_buf)
    return len(filter(bufnrs, "v:val == ".diff_buf)) > 0
  endif
  return v:false
endfunction

function! s:do_diff(buf) abort
  if s:is_current_diffbuf_showed(a:buf)
    return
  endif
  let fname = getbufvar(a:buf, "diff_filename", "")
  if len(fname) > 0
    call fugitive#DiffClose()
    exec printf("leftabove vert diffsplit %s | doautocmd <nomodeline> BufReadCmd", fname)
    call setbufvar(a:buf, "diff_buf", bufnr(fname, v:true))
    wincmd p
  endif
endfunction

function! s:diff_with_ctx(bang, buf) abort
  if a:bang && (s:auto_diff || s:is_current_diffbuf_showed(a:buf))
    let s:auto_diff = v:false
    exec printf("bdel %s", s:get_diffbuf(a:buf))
    return
  endif
  if a:bang
    let s:auto_diff = v:true
  endif
  call s:do_diff(a:buf)
endfunction

let s:auto_diff = v:false
function! s:qf_diff(qfid) abort
  let buf = bufnr()
  let diffs = s:context.items[s:qf_idx(a:qfid)-1].diff
  if len(diffs) == 0
    return
  endif
  let diff = diffs[0]
  call setbufvar(buf, "diff_filename", diff.filename)

  command! -bang -buffer GDiffWithCtx call s:diff_with_ctx(<bang>0, bufnr())
  nnoremap <buffer> \d <cmd>GDiffWithCtx<cr>
  nnoremap <buffer> \D <cmd>GDiffWithCtx!<cr>

  if !s:is_qfwin_opened() || !s:current_qfid_equal(a:qfid)
    return
  endif
  if s:auto_diff
    call s:do_diff(buf)
  endif
endfunction

function! s:unload_diffbuf() abort
  let buf = bufnr()
  let diff_buf = s:get_diffbuf(buf)
  if diff_buf > 0 && bufloaded(diff_buf)
    exec diff_buf . "bunload!"
  endif
endfunction

function! s:qfugitive() abort
  let qflist = getqflist({'items': 0, 'id': 0, 'context': 0, 'size': 0})
  if qflist.size == 0
    return
  endif
  let items = qflist.items
  let module = items[0].module
  "https://github.com/tpope/vim-fugitive/blob/593f831d6f6d779cbabb70a4d1e6b1b1936a88af/autoload/fugitive.vim#L5645
  if stridx(module, ":2:") >=0 || stridx(module, ":3:") >=0
    return 
  endif
  let s:context = qflist.context
  let qfid = qflist.id
  exec printf("augroup qfugitive:autodiff:qfid:%s", qfid)
  exec "autocmd!"
  for idx in range(0, len(items)-1)
    let item = get(items, idx)
    let buf = item["bufnr"]
    exec printf("autocmd BufReadPost <buffer=%s> call s:qf_diff(%s)", buf, qfid)
    exec printf("autocmd BufDelete <buffer=%s> call s:unload_diffbuf()", buf)
  endfor
  exec "augroup END"
endfunction

augroup qfugitive
  autocmd!
  autocmd QuickFixCmdPost cfugitive-difftool call s:qfugitive()
augroup END
