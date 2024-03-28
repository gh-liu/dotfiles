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
" CompilerSet makeprg=golangci-lint\ run\ --out-format=tab


" Define the patterns that will be recognized by QuickFix when parsing the
" output of golangci-lint command that use this errorforamt.
" More information at:
" http://vimdoc.sourceforge.net/htmldoc/quickfix.html#errorformat

CompilerSet errorformat =%f:%l:%c:\ %m  " Start of multiline unspecified string is 'filename:linenumber:columnnumber:'

" CompilerSet errorformat =%-G#\ %.%#                                 " Ignore lines beginning with '#' ('# command-line-arguments' line sometimes appears?)
" CompilerSet errorformat+=%-G%.%#panic:\ %m                          " Ignore lines containing 'panic: message'
" CompilerSet errorformat+=%Ecan\'t\ load\ package:\ %m               " Start of multiline error string is 'can\'t load package'
" CompilerSet errorformat+=%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:%c:\ %m " Start of multiline unspecified string is 'filename:linenumber:columnnumber:'
" CompilerSet errorformat+=%A%\\%%(%[%^:]%\\+:\ %\\)%\\?%f:%l:\ %m    " Start of multiline unspecified string is 'filename:linenumber:'
" CompilerSet errorformat+=%C%*\\s%m                                  " Continuation of multiline error message is indented
" CompilerSet errorformat+=%-G%.%#                                    " All lines not matching any of the above patterns are ignored


let &cpo = s:save_cpo
unlet s:save_cpo

" restore Vi compatibility settings
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 ts=2 et
