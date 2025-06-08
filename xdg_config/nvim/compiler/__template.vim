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

"CompilerSet errorformat=
"CompilerSet errorformat+=


let &cpo = s:cpo_save
unlet s:cpo_save
