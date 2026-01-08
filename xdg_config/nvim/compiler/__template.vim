" ============================================================================
" Compiler Template
" ============================================================================
" Purpose: Define errorformat patterns for parsing compiler output into quickfix
"
" Special characters in errorformat:
"   %E  - Start of a multi-line error (error level)
"   %W  - Start of a multi-line warning (warning level)
"   %A  - Start of a multi-line message (generic)
"   %C  - Continuation line of a multi-line message
"   %Z  - End of a multi-line message
"   %f  - File name
"   %l  - Line number
"   %c  - Column number
"   %m  - Error message text
"   %v  - Virtual column number (for stack offsets)
"   %t  - Single character error type (e/w/i)
"   %n  - Error number
"   %*{...} - Match regex pattern {...}
"   %.%# - Match any remaining text (wildcard)
"   %\\  - Literal backslash
"   %-G  - Global: match but ignore (don't add to quickfix)
"   %+G  - Global: match as non-error message (add to quickfix)
"   %=   - Separator: following patterns only if previous matched
"   ^   - errorformat^=  : Prepend to start of errorformat
"   +   - errorformat+=  : Append to end of errorformat
"   -   - errorformat-=  : Remove from errorformat
" ============================================================================

" Check if this compiler is already loaded to prevent duplication
if exists("current_compiler")
  finish
endif
let current_compiler = "__template" " NOTE: SET YOUR COMPILER NAME HERE

" Define CompilerSet command if not available (for older Vim versions)
if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

" Save current 'cpoptions' setting and modify for pattern matching
let s:cpo_save = &cpo
set cpo-=C " 'C' flag: continue matching after line break

" ============================================================================
" Compiler Configuration
" ============================================================================

" Set the build command (e.g., makeprg=python\ -m\ pytest)
"CompilerSet makeprg=

" Set error format patterns (first pattern clears existing)
"   %E%f:%l:\ %m        - "file.py:123: error message" (error level)
"   %W%f:%l:\ %m        - "file.py:123: warning message" (warning level)
"CompilerSet errorformat=
"CompilerSet errorformat+=

" Restore original 'cpoptions' setting
let &cpo = s:cpo_save
unlet s:cpo_save
