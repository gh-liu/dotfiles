" Git output syntax extensions

" Highlight git stash list entries
" Git stash list format: hash date stash@{n} message
" Example: 83f296c 2026-01-07 stash@{0}  commit message
syn match gitStashIndex   /stash@{\d\+}/ contains=gitStashBraces
syn match gitStashDate    /\s\zs\d\{4\}-\d\{2\}-\d\{2\}\ze\s.*stash@{/
syn match gitStashHash    /^\x\{4,10\}\ze\s.*stash@{/
syn match gitStashBraces  /[{}]/       contained

hi def link gitStashHash     Identifier
hi def link gitStashDate     Number
hi def link gitStashIndex    Function
hi def link gitStashBraces   Delimiter
