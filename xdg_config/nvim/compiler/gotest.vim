" Compiler:	gotest
" Optimized for go test

if exists("current_compiler")
  finish
endif
let current_compiler = "gotest"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=go\ test

" --- FAIL: TestName (start of a new error entry)
CompilerSet errorformat=\%E---\ FAIL:\%m
" file.go:123: error message (continuation line with file location)
CompilerSet errorformat+=\%C%*\\s%f:%l:\%m
"     file.go:123: error message (indented continuation line for verbose output)
CompilerSet errorformat+=\%C%\\s%f:%l:\%m
"     github.com/user/repo/file.go:123 +0xabc (stack trace with offset)
CompilerSet errorformat+=\%C%\\s%#%f:%l\ +0x%v
" FAIL (summary line - ignore)
CompilerSet errorformat+=%-GFAIL
" ok github.com/user/package (summary line - ignore)
CompilerSet errorformat+=%-Gok\ %\\S\+
" FAIL github.com/user/package (summary line - ignore)
CompilerSet errorformat+=%-GFAIL\ %\\S\+
" PASS (summary line - ignore)
CompilerSet errorformat+=%-GPASS

let &cpo = s:cpo_save
unlet s:cpo_save
