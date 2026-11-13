" dispatch.vim Rex strategy

if exists('g:autoloaded_dispatch_rex')
  finish
endif
let g:autoloaded_dispatch_rex = 1

let s:waiting = {}

function! dispatch#rex#handle(request) abort
  if empty($REX_BLOCK) || !executable('rex')
    return 0
  endif
  if a:request.action ==# 'make'
    let script = dispatch#prepare_make(a:request)
  elseif a:request.action ==# 'start'
    let script = dispatch#prepare_start(a:request)
  else
    return 0
  endif

  " Preserve the editor's environment, but let Rex supply the new pane's identity.
  let environment = map(filter(items(environ()), 'v:val[0] !~# "^REX_"'),
        \ 'shellescape(v:val[0] . "=" . v:val[1])')
  let command = 'env ' . join(environment, ' ') . ' ' . shellescape(&shell)
        \ . ' ' . &shellcmdflag . ' ' . shellescape(script)
  let output = system('rex --autostart=false run --json --split=below'
        \ . ' --block ' . shellescape($REX_BLOCK)
        \ . ' --cwd ' . shellescape(a:request.directory)
        \ . ' --label ' . shellescape(a:request.title)
        \ . (a:request.action ==# 'make' || a:request.background ? ' --focus=false' : '')
        \ . ' --shell=none -- ' . command)
  if v:shell_error
    echohl WarningMsg
    echomsg 'Rex dispatch failed: ' . trim(output)
    echohl None
    return 0
  endif
  let a:request.rex_block = json_decode(output).block_ids[0]
  if a:request.action ==# 'start'
    call filter(s:waiting, '!filereadable(v:key . ".complete")')
    let s:waiting[a:request.file] = a:request
  elseif !dispatch#has_callback()
    call timer_start(100, function('s:poll', [a:request]), {'repeat': -1})
  endif
  return 1
endfunction

function! s:poll(request, timer) abort
  if filereadable(a:request.file . '.complete')
    call timer_stop(a:timer)
    call dispatch#complete(a:request)
  endif
endfunction

function! dispatch#rex#activate(pid) abort
  for [file, request] in items(copy(s:waiting))
    if filereadable(file . '.complete')
      call remove(s:waiting, file)
    elseif dispatch#pid(request) == a:pid
      call system('rex --autostart=false focus ' . shellescape(request.rex_block))
      return !v:shell_error
    endif
  endfor
  return 0
endfunction
