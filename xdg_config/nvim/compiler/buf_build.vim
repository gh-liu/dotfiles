" ============================================================================
" Compiler: bufbuild
" Purpose: Parse `buf build` / `buf lint` output for quickfix navigation
" Optimized for: buf build, buf lint
" ============================================================================

if exists("current_compiler")
  finish
endif
let current_compiler = "bufbuild"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

" Build command: `buf build` validates and compiles proto files
CompilerSet makeprg=buf\ build

" ----------------------------------------------------------------------------
" Pattern 1: Primary error format with line and column
"   %E            - Start of multi-line error (error level)
"   %f            - File name (e.g., api/rpc.proto)
"   :             - Literal colon
"   %l            - Line number
"   :             - Literal colon
"   %c            - Column number
"   :             - Literal colon
"   %m            - Error message text
" Matches: "api/rpc.proto:414:11:cannot find `foo.bar` in this scope"
CompilerSet errorformat=%E%f:%l:%c:%m

" ----------------------------------------------------------------------------
" Pattern 2: Error with only line number (no column)
"   %E            - Start of multi-line error
"   %f            - File name
"   :             - Literal colon
"   %l            - Line number
"   :             - Literal colon
"   %m            - Error message text
" Matches: "api/foo.proto:7:imported file does not exist"
CompilerSet errorformat+=%E%f:%l:%m

" ----------------------------------------------------------------------------
" Pattern 3: File-only error (no line/column, e.g., file-level issues)
"   %E            - Start of multi-line error
"   %f            - File name
"   :             - Literal colon
"   \             - Literal space
"   %m            - Error message text
" Matches: "api/foo.proto: some file-level error"
CompilerSet errorformat+=%E%f:\ %m

" ----------------------------------------------------------------------------
" Ignore patterns (suppress non-error output)
"   %-G%.%#       - Drop any line not matched above (keeps quickfix clean)
" Uncomment the line below if you want to drop unmatched lines entirely:
" CompilerSet errorformat+=%-G%.%#

" ----------------------------------------------------------------------------
" Restore original 'cpoptions'
" ----------------------------------------------------------------------------
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set ft=vim
