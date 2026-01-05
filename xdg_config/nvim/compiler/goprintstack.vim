" Compiler:	goprintstack
" For parsing Go stack traces (goroutine dumps)

if exists("current_compiler")
  finish
endif
let current_compiler = "goprintstack"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

" goroutine 1 [running]: (header line - ignore, start of stack trace)
CompilerSet errorformat=%-Ggoroutine\ %.%#
"     github.com/user/repo/file.go:123: error message (end of multi-line entry)
CompilerSet errorformat=%Z\ %#%f:%l%m
" error message (start of multi-line entry)
CompilerSet errorformat=%A%m

let &cpo = s:cpo_save
unlet s:cpo_save
