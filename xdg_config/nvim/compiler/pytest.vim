" ============================================================================
" Compiler: pytest
" Purpose: Parse pytest output for quickfix navigation
" Optimized for: python3 -m pytest
" ============================================================================

CompilerSet makeprg=python3\ -m\ pytest

" ----------------------------------------------------------------------------
" Cleanup: Remove any existing general message formats (%+G) that might interfere
"   split(&efm, ',')  - Split current errorformat by comma into list
"   =~#               - Case-sensitive regex match
"   %+G               - Global message format (non-error)
"   escape()          - Escape backslashes for command execution
" ----------------------------------------------------------------------------
for efm in split(&efm, ',')
  if efm =~# '%+G'
    exe 'CompilerSet errorformat-=' . escape(efm, '\\ ')
  endif
endfor

" ----------------------------------------------------------------------------
" Prepend patterns (errorformat^=)
" ----------------------------------------------------------------------------

" Ignore timestamp lines that look like file:line:column
"   %-G                - Global ignore: match but don't add to quickfix
"   %.%#               - Match any text (wildcard)
"   \%d                - Literal '%' followed by digit (escaped %)
"   \\{4}              - Exactly 4 digits (date year)
"   \ %\               - Space followed by literal '%'
" Pattern matches: "2025-06-14 22:29:59"
CompilerSet errorformat^=%-G%.%#%\\d%\\{4}-%\\d%\\{2}-%\\d%\\{2}\ %\\d%\\{2}:%\\d%\\{2}%.%#

" ----------------------------------------------------------------------------
" Append patterns (errorformat+=)
" ----------------------------------------------------------------------------

" Pattern group 1: Python traceback format
" Matches multi-line Python errors starting with "File"
"   %E                 - Start of multi-line error (error level)
"   %f                 - File name
"   %l                 - Line number
"   \%                 - Literal '%' (escape)
"   : in %.%#          - Literal ": in " followed by any text
" Matches: 'File "xxx.py", line 123, in some_func'
CompilerSet errorformat+=
    \%E%f:%l:\ in\ %.%#,
    " %C  - Continuation line (part of multi-line error)
    " \   - Literal space
    " %m  - Error message text
    " Matches indented error message lines
    \%C\ %m,
    " %Z  - End of multi-line error
    " %.%# - Any remaining text
    \%Z%.%#,
    " Pattern group 2: FAILED marker (start of new error entry)
    "   %E      - Start of multi-line error
    "   FAILED  - Literal "FAILED" text
    "   %.%#    - Any text after "FAILED"
    \%EFAILED%.%#,
    " Pattern group 3: File:line format within multi-line
    "   %C      - Continuation line
    "   %f      - File name
    "   %l      - Line number
    "   %m      - Error message
    " Matches: 'file.py:123: error message'
    \%C%f:%l:\ %m,
    " %Z  - End of multi-line entry
    \%Z%.%#

" ----------------------------------------------------------------------------
" Ignore patterns (summary lines to exclude from quickfix)
"   %-G                - Global ignore (match but don't add to quickfix)
"   ===.*===           - Separator lines (=== ... ===)
"   passed             - Summary word "passed"
"   failed             - Summary word "failed"
"   ERRORS             - Summary word "ERRORS"
"   warnings summary   - Summary header
"   %*\\s              - Match any whitespace (* is greedy)
"   %*\\d              - Match any digits
" ----------------------------------------------------------------------------
CompilerSet errorformat+=
    \%-G===.*===,
    \%-Gpassed,
    \%-Gfailed,
    \%-GERRORS,
    \%-Gwarnings\ summary,
    " Matches: "     3 passed" or "1 failed" (indentation + count + word)
    \%-G%*\\s%*\\d\ passed,
    \%-G%*\\s%*\\d\ failed
