if exists('g:loaded_envrc_load')
  " Allow re-sourcing this file to refresh autocmd/command definitions.
  " (Useful when iterating without restarting Neovim.)
endif
let g:loaded_envrc_load = 1

" Parse .envrc lines like:
"   export FOO=bar
"   export BAZ="$FOO"
"
" Then write into current (n)vim process environment via: let $FOO = "bar"
" Notes:
" - This only affects the current nvim process and its future child processes.
" - It does NOT execute shell; only parses matching `export KEY=VALUE` lines.
" - Autoload is OFF by default; enable per-buffer with:
"     :let b:envrc_autoload=1

let s:interpolation = '\\\=\${.\{-\}}\|\\\=\$\w\+'

function! s:lookup(key, env) abort
  if a:key ==# '\n'
    return "\n"
  elseif a:key =~# '^\\'
    return a:key[1:-1]
  endif
  let var = matchstr(a:key, '^\${\zs.*\ze}$\|^\$\zs\(.*\)$')
  if exists('$'.var)
    return eval('$'.var)
  else
    return get(a:env, var, '')
  endif
endfunction

function! s:parse_lines(lines) abort
  let env = {}
  for line in a:lines
    let matches = matchlist(line, '\v\C^%(export\s+)=([[:alnum:]_.]+)%(\s*\=\s*|:\s{-})(''%(\\''|[^''])*''|"%(\\"|[^"])*"|[^#]+)=%( *#.*)?$')
    if empty(matches)
      continue
    endif
    let key = matches[1]
    let value = matches[2]

    " Keep the first occurrence (dotenv.vim behavior)
    if has_key(env, key)
      continue
    endif

    " Double-quoted values: handle escapes more like shell/dotenv
    if value =~# '^\s*".*"\s*$'
      let value = substitute(value, '\n', "\n", 'g')
      let value = substitute(value, '\\\ze[^$]', '', 'g')
    endif

    " Strip surrounding quotes (single or double)
    let value = substitute(value, '^\s*\([''"]\)\=\(.\{-\}\)\1\s*$', '\2', '')

    " Interpolate $VAR / ${VAR} (prefers current process env, then this file)
    let value = substitute(value, s:interpolation, '\=s:lookup(submatch(0), env)', 'g')

    let env[key] = value
  endfor
  return env
endfunction

function! s:apply_env(env) abort
  for key in sort(keys(a:env))
    execute 'let $'.key.' = '.string(a:env[key])
  endfor
endfunction

function! s:load_buf(bufnr) abort
  let lines = getbufline(a:bufnr, 1, '$')
  let env = s:parse_lines(lines)
  call s:apply_env(env)
  return env
endfunction

function! s:on_write(bufnr) abort
  if getbufvar(a:bufnr, 'envrc_autoload', 0) != 1
    return
  endif
  try
    call s:load_buf(a:bufnr)
    echohl Comment | echom '[envrc] loaded into $ENV' | echohl None
  catch
    echohl ErrorMsg | echom '[envrc] failed: ' . v:exception | echohl None
  endtry
endfunction

augroup EnvrcLoad
  autocmd!
  autocmd BufWritePost .envrc call <SID>on_write(str2nr(expand('<abuf>')))
augroup END

function! s:envrc_load_cmd(bang, bufnr) abort
  if a:bang
    let cur = getbufvar(a:bufnr, 'envrc_autoload', 0)
    let next = (cur == 1) ? 0 : 1
    call setbufvar(a:bufnr, 'envrc_autoload', next)
    if next == 1
      call s:load_buf(a:bufnr)
      echohl Comment | echom '[envrc] autoload enabled' | echohl None
    else
      echohl Comment | echom '[envrc] autoload disabled' | echohl None
    endif
    return
  endif
  call s:load_buf(a:bufnr)
endfunction

" Manual trigger:
" - :EnvrcLoad   loads once (does not change b:envrc_autoload)
" - :EnvrcLoad!  toggles b:envrc_autoload for this buffer
command! -bar -bang EnvrcLoad call <SID>envrc_load_cmd(<bang>0, bufnr('%'))
