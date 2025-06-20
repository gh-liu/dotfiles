" Compiler:	python

" see
":h makeprg
":h errorformat

if exists("current_compiler")
  finish
endif
let current_compiler = "python"

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

CompilerSet makeprg=python

" Use each file and line of Tracebacks (to see and step through the code executing).
CompilerSet errorformat=%A%\\s%#File\ \"%f\"\\,\ line\ %l\\,\ in%.%#
" Include failed toplevel doctest example.
CompilerSet errorformat+=%+CFailed\ example:%.%#
" Ignore big star lines from doctests.
CompilerSet errorformat+=%-G*%\\{70%\\}
" Ignore most of doctest summary. x2
CompilerSet errorformat+=%-G%*\\d\ items\ had\ failures:
CompilerSet errorformat+=%-G%*\\s%*\\d\ of%*\\s%*\\d\ in%.%#

" SyntaxErrors (%p is for the pointer to the error column).
" Source: http://www.vim.org/scripts/script.php?script_id=477
CompilerSet errorformat+=%E\ \ File\ \"%f\"\\\,\ line\ %l
" %p must come before other lines that might match leading whitespace
CompilerSet errorformat+=%-C%p^
CompilerSet errorformat+=%+C\ \ %m
CompilerSet errorformat+=%Z\ \ %m

" I don't use \%-G%.%# to remove extra output because most of it is useful as
" context for the actual error message. I also don't include %+G because
" they're unnecessary if I'm not squelching most output.
" If I was using %+G, I'd probably want something like these. There are so
" many, that I don't bother.
"      \%+GTraceback%.%#,
"      \%+G%*\\wError%.%#,
"      \%+G***Test\ Failed***%.%#
"      \%+GExpected%.%#,
"      \%+GGot:%.%#,

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:set sw=2 sts=2:
