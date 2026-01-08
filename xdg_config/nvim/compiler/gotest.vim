" ============================================================================
" Compiler: gotest
" Purpose: Parse `go test` output for quickfix navigation
" Optimized for: go test, go test -v
" ============================================================================

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

" ----------------------------------------------------------------------------
" Pattern 1: Primary error format (start of new error entry)
"   \%E           - Literal '%' followed by 'E' (escaped)
"   %E            - Start of multi-line error (error level)
"   %f            - File name
"   :             - Literal colon
"   %l            - Line number
"   : %m          - Literal ": " followed by error message
" Matches: "file.go:123: error message"
CompilerSet errorformat=\%E%f:%l:\ %m

" ----------------------------------------------------------------------------
" Pattern 2: Indented file:line format (continuation for verbose output)
"   \%C           - Literal '%' followed by 'C' (escaped)
"   %C            - Continuation line (part of multi-line error)
"   \\s           - Literal space (escaped space)
"   %#            - Match any non-space characters (skip leading whitespace)
"   %f            - File name
"   :             - Literal colon
"   %l            - Line number
"   : %m          - Literal ": " followed by error message
" Matches: "    file.go:123: error message"
CompilerSet errorformat+=\%C\\s%#%f:%l:\ %m

" ----------------------------------------------------------------------------
" Pattern 3: Stack trace with offset (continuation)
"   %C            - Continuation line
"   \\s           - Literal space
"   %#            - Skip leading whitespace
"   %f            - File name
"   :             - Literal colon
"   %l            - Line number
"   \ +           - Literal space "+"
"   0x            - Literal "0x" (hex prefix)
"   %v            - Virtual column / hex offset value
" Matches: "    github.com/user/repo/file.go:123 +0xabc"
CompilerSet errorformat+=\%C\\s%#%f:%l\ +0x%v

" ----------------------------------------------------------------------------
" Ignore patterns (summary lines to exclude from quickfix)
"   %-G            - Global ignore (match but don't add to quickfix)
"   === \ %.%#     - "=== RUN TestName" test start lines
"   --- PASS:      - Test passed summary
"   --- FAIL:      - Test failed summary
"   FAIL%.%#       - "FAIL" lines
"   ok             - "ok" summary (test suite passed)
"   PASS           - "PASS" summary
"   exit status    - Exit status lines
" ----------------------------------------------------------------------------
" Ignore test runner headers: "=== RUN", "=== CONT", etc.
CompilerSet errorformat+=%-G===\ %.%#
" Ignore passed test summaries: "--- PASS: TestName"
CompilerSet errorformat+=%-G---\ PASS:\ %.%#
" Ignore failed test summaries: "--- FAIL: TestName"
CompilerSet errorformat+=%-G---\ FAIL:\ %.%#
" Ignore standalone FAIL lines
CompilerSet errorformat+=%-GFAIL%.%#
" Ignore "ok" summary (e.g., "ok  github.com/user/repo  0.123s")
CompilerSet errorformat+=%-Gok
" Ignore standalone PASS lines
CompilerSet errorformat+=%-GPASS
" Ignore exit status lines: "exit status 1"
CompilerSet errorformat+=%-Gexit\ status\ %.%#

" ----------------------------------------------------------------------------
" Restore original 'cpoptions'
" ----------------------------------------------------------------------------
let &cpo = s:cpo_save
unlet s:cpo_save
