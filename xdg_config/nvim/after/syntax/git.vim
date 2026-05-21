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

" Fold each commit in custom pretty `git log` output (e.g.
"   git log --pretty="%h%d %s  %aN (%cr)" -L :func:file
" ), where each entry starts with an abbreviated hash instead of
" `commit <fullhash>` and is therefore not covered by the runtime
" gitHead fold region.
if getline(1) =~# '^\x\{7,\} '
  syn region gitLogEntry matchgroup=gitHashAbbrev start=/^\x\{7,\}\ze / end=/^\%(\x\{7,\} \)\@=/ keepend fold contains=gitDiff,gitDiffMerge,@NoSpell
elseif getline(1) =~# '^[|\/\\_ ]\{-\}\*[|\/\\_ ]\{-\} \x\{7,\} '
  syn region gitLogEntry matchgroup=gitHashAbbrev start=/^[|\/\\_ ]\{-\}\*[|\/\\_ ]\{-\} \zs\x\{7,\}\ze / end=/^\%([|\/\\_ ]\{-\}\*[|\/\\_ ]\{-\} \x\{7,\} \)\@=/ keepend fold contains=gitGraph,gitDiff,gitDiffMerge,@NoSpell
endif
