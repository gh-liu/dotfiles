" ============================================================================
" Compiler: python
" Purpose: Parse Python traceback output for quickfix navigation
" Optimized for: python, python3 error messages
" ============================================================================

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

" ----------------------------------------------------------------------------
" Python traceback error format (multi-line pattern)
"
" Example traceback:
"   Traceback (most recent call last):
"     File "/path/to/file.py", line 123, in some_func
"       <code line>
"       ^ (error pointer for syntax errors)
"   ErrorMessage: description
"
" Pattern breakdown:
" ----------------------------------------------------------------------------
" Pattern 1: Continuation line (any indented text)
"   %C            - Continuation line (part of multi-line error)
"   \             - Literal space
"   %.%#          - Match any remaining text on line
" Matches indented lines in traceback
CompilerSet errorformat=
    \%C\ %.%#,
" ----------------------------------------------------------------------------
" Pattern 2: File line (start of new error entry)
"   %A            - Start of multi-line message (generic)
"   \             - Literal space
"   File\         - Literal "File "
"   \"            - Literal quote (escaped)
"   %f            - File name
"   \"            - Literal quote
"   \\,           - Literal comma (escaped)
"   line\         - Literal "line "
"   %l            - Line number
"   %.%#          - Match remaining text (e.g., ", in some_func")
" Matches: '  File "/path/to/file.py", line 123, in some_func'
    \%A\ \ File\ \"%f\"\\,\ line\ %l%.%#,
" ----------------------------------------------------------------------------
" Pattern 3: End of multi-line entry (error message)
"   %Z            - End of multi-line error
"   %[%^\ ]       - Match any character except space (start of line anchor)
"   %\@=          - Zero-width match (lookahead, doesn't consume)
"   %m            - Error message text
" The [%^\ ]%\@= ensures message starts at beginning of line (no leading space)
" This distinguishes error messages from continuation lines (which have spaces)
    \%Z%[%^\ ]%\\@=%m

" ----------------------------------------------------------------------------
" Restore original 'cpoptions'
" ----------------------------------------------------------------------------
let &cpo = s:cpo_save
unlet s:cpo_save
