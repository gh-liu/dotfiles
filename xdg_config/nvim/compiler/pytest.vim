" Compiler:	pytest
" Optimized for python3 -m pytest

CompilerSet makeprg=python3\ -m\ pytest

" Remove any existing general message formats that might interfere
for efm in split(&efm, ',')
  if efm =~# '%+G'
    exe 'CompilerSet errorformat-=' . escape(efm, '\\ ')
  endif
endfor

" 2025-06-14 22:29:59 (timestamp that looks like file:line:column - ignore)
CompilerSet errorformat^=%-G%.%#%\\d%\\{4}-%\\d%\\{2}-%\\d%\\{2}\ %\\d%\\{2}:%\\d%\\{2}%.%#

"     File "xxx.py", line 123, in some_func (start of new error entry)
"   error message (continuation line)
"   any text (end of multi-line entry)
CompilerSet errorformat+=
    \%E%\\s%#File\ \"%f\"\\,\ line\ %l\\,\ in%.%#,
    \%C\ %m,
    \%Z%.%#,
    " FAILED (start of new error entry)
    \%EFAILED%.%#,
    " file.py:123: error message (continuation line)
    \%C%f:%l:\ %m,
    " any text (end of multi-line entry)
    \%Z%.%#

" ==================================== (separator lines - ignore)
" passed (summary word - ignore)
" failed (summary word - ignore)
" ERRORS (summary word - ignore)
" warnings summary (summary header - ignore)
"     3 passed (count summary - ignore)
"     1 failed (count summary - ignore)
CompilerSet errorformat+=
    \%-G===.*===,
    \%-Gpassed,
    \%-Gfailed,
    \%-GERRORS,
    \%-Gwarnings\ summary,
    \%-G%*\\s%*\\d\ passed,
    \%-G%*\\s%*\\d\ failed
