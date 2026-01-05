" Compiler:	python
" Optimized error format for Python tracebacks

if exists("current_compiler")
  finish
endif
let current_compiler = "python"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=python

"   File "xxx.py", line 123, in some_func (start of new error entry)
" ****************************************************************************** (separator line - ignore)
" 2 items had failures: (summary line - ignore)
" 1 of 2 in xxx (summary line - ignore)
"   File "xxx.py", line 123 (start of syntax error)
"       ^ (error pointer line - ignore)
"     error message (continuation line, include)
"     error message (end of multi-line entry)
CompilerSet errorformat=
    \%A%\\s%#File\ \"%f\"\\,\ line\ %l\\,\ in%.%#,
    \%-G*%\\{70%\\},
    \%-G%*\\d\ items\ had\ failures:
    \%-G%*\\d\ of\*\\d\ in%.%#,
    \%E\ File\ \"%f\"\\\,\ line\ %l,
    \%-C%p^,
    \%+C\ \%m,
    \%Z\ \%m

let &cpo = s:cpo_save
unlet s:cpo_save
