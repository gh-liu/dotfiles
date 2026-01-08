" ============================================================================
" Compiler: goprintstack
" Purpose: Parse Go stack traces (goroutine dumps) for quickfix navigation
" For use with: runtime/pprof, panic output, debug.PrintStack()
" ============================================================================

if exists("current_compiler")
  finish
endif
let current_compiler = "goprintstack"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

let s:cpo_save = &cpo
set cpo-=C

" ----------------------------------------------------------------------------
" Pattern 1: Ignore goroutine header lines
"   %-G            - Global ignore: match but don't add to quickfix
"   goroutine      - Literal "goroutine"
"   \%             - Literal space
"   %\             - Literal space
"   \%[            - Literal '[' (escape)
"   running        - Literal "running"
"   \]:            - Literal "]:"
" Matches: "goroutine 1 [running]:"
CompilerSet errorformat=%-Ggoroutine\ %\[running\]:
" ----------------------------------------------------------------------------
" Pattern 2: Stack trace source location lines (continuation)
"   %C            - Continuation line (part of multi-line error)
"   \\t           - Literal tab character
"   %#            - Match any non-digit characters (skip leading text)
"   %f            - File name
"   :             - Literal colon
"   %l            - Line number
"   \ +           - Literal space, "+"
"   0x            - Literal "0x" (hex prefix)
"   %v            - Virtual column / hex offset value
" Matches: "    /path/to/file.go:123 +0xabc"
CompilerSet errorformat+=%C\\t%#%f:%l\ +0x%v
" ----------------------------------------------------------------------------
" Pattern 3: Error message (start of multi-line entry)
"   %A            - Start of multi-line message (generic)
"   %m            - Error message text (entire line)
" Matches any error/panic message line
CompilerSet errorformat+=%A%m

" ----------------------------------------------------------------------------
" Restore original 'cpoptions'
" ----------------------------------------------------------------------------
let &cpo = s:cpo_save
unlet s:cpo_save
