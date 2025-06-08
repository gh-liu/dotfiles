if exists("current_compiler")
  finish
endif
let current_compiler = "__template" "NOTE: SET YOUR COMPILER

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

"CompilerSet makeprg=

CompilerSet efm=%-Ggoroutine\ %.%#
CompilerSet efm+=%Z\ %#%f:%l%m
CompilerSet efm+=%A%m


let &cpo = s:cpo_save
unlet s:cpo_save
