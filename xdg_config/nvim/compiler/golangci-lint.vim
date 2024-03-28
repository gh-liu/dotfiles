if exists("g:current_compiler")
  finish
endif
let g:current_compiler = "golangci-lint"

" don't spam the user when Vim is started in Vi compatibility mode
let s:cpo_save = &cpo
set cpo&vim

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:save_cpo = &cpo
set cpo-=C

" CompilerSet makeprg=golangci-lint\ run
CompilerSet makeprg=golangci-lint\ run\ --out-format=line-number

" Define the patterns that will be recognized by QuickFix when parsing the
" output of golangci-lint command that use this errorforamt.
" More information at:
" http://vimdoc.sourceforge.net/htmldoc/quickfix.html#errorformat

CompilerSet errorformat=%A%f:%l:%c:\ %m,%-Z%p^,%-C%.%#

let &cpo = s:save_cpo
unlet s:save_cpo

" restore Vi compatibility settings
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 ts=2 et
