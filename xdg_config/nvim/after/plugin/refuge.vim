" refuge.vim - Review workflow for vim-fugitive (review + fugitive)
" Pure Fugitive-based code review without qfugitive dependency
"
" Workflow A: By commit
"   :GRCommit [target]         - Show commits (default: @..FETCH_HEAD)
"   GFiles !                   - List files in current commit
"   dd / :Gvdiffsplit! !^      - Diff: !^ vs ! (this commit's changes)
"
" Workflow B: By file
"   :GRFiles [target]          - Show changed files (default: merge-base..target)
"   :Gvdiffsplit! refs/refuge/base<CR>  - Diff: saved base vs target (file changes)
"
"

if exists('g:loaded_refuge') || !exists('*FugitiveGitDir')
    finish
endif
let g:loaded_refuge = 1

" Get or set the diff target
function! s:GetRepoKey() abort
    return FugitiveGitDir()
endfunction

function! s:GetDiffTarget(args) abort
    let repo = s:GetRepoKey()
    let targets = get(g:, 'refuge_diff_targets', {})
    if len(a:args) > 0
        let targets[repo] = a:args
        let g:refuge_diff_targets = targets
    endif
    return get(targets, repo, 'FETCH_HEAD')
endfunction

" Get merge-base using fugitive#Execute
function! s:GetMergeBase(target) abort
    let dir = FugitiveGitDir()
    let result = fugitive#Execute(dir, 'merge-base', '@', a:target)
    return result.exit_status == 0 ? trim(join(result.stdout, '')) : '@'
endfunction

function! s:SetReviewBaseRef(base) abort
    let dir = FugitiveGitDir()
    return fugitive#Execute(dir, 'update-ref', 'refs/refuge/base', a:base)
endfunction

" Complete refs (branches, HEAD references)
function! s:CompleteRefs(ArgLead, CmdLine, CursorPos) abort
    let dir = FugitiveGitDir()
    let heads = ['HEAD', 'FETCH_HEAD', 'ORIG_HEAD', 'MERGE_HEAD', 'REBASE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD']
    let heads = filter(heads, 'filereadable(dir . "/" . v:val) || v:val =~# "HEAD$"')

    let result = fugitive#Execute(dir, 'rev-parse', '--symbolic', '--branches')
    if result.exit_status == 0
        let heads += filter(result.stdout, 'len(v:val) > 0')
    endif
    

    return filter(uniq(sort(heads)), 'stridx(v:val, a:ArgLead) == 0')
endfunction

" Parse args: smart range parsing
" - Branch name → @ .. branch
" - A..B, A...B → as-is
" - A.., A... → A .. @, A ... @
" - ..B, ...B → @ .. B, @ ... B
" - No args → @ .. FETCH_HEAD (or smart default)
function! s:ParseArgs(args) abort
    let input = trim(a:args)
    
    if empty(input)
        " No args: use cached target or default
        return { 'left': '@', 'right': s:GetDiffTarget(''), 'sep': '..' }
    endif
    
    if input =~# '\.\.\.'
        let parts = split(input, '\.\.\.', 1)
        return {
            \ 'left': empty(get(parts, 0, '')) ? '@' : parts[0],
            \ 'right': empty(get(parts, 1, '')) ? '@' : parts[1],
            \ 'sep': '...',
            \ }
    endif

    if input =~# '\.\.'
        let parts = split(input, '\.\.', 1)
        return {
            \ 'left': empty(get(parts, 0, '')) ? '@' : parts[0],
            \ 'right': empty(get(parts, 1, '')) ? '@' : parts[1],
            \ 'sep': '..',
            \ }
    endif

    " Simple branch/ref name: @ .. branch
    return { 'left': '@', 'right': input, 'sep': '..' }
endfunction

" Get files for current commit if in commit buffer
function! s:GetCommitParent(commit) abort
    let dir = FugitiveGitDir()
    let result = fugitive#Execute(dir, 'rev-list', '--parents', '-n', '1', a:commit)
    if result.exit_status != 0
        return ''
    endif

    let commits = split(trim(join(result.stdout, ' ')))
    return len(commits) > 1 ? commits[1] : ''
endfunction

function! s:GetCommitFiles(bang) abort
    let ftype = get(b:, 'fugitive_type', '')
    if ftype ==# 'commit'
        let commit = fugitive#Object(@%)
        let parent = s:GetCommitParent(commit)
        if empty(parent)
            execute 'G' . a:bang . ' show --name-status ' . commit
        else
            execute 'G' . a:bang . ' difftool --name-status ' . parent . ' ' . commit
        endif
        return 1
    endif
    return 0
endfunction

function! s:GRCommit(args, bang) abort
    let range = s:ParseArgs(a:args)
    execute 'Gclog' . a:bang . ' ' . range.left . range.sep . range.right
endfunction

function! s:GRFiles(args, bang) abort
    if s:GetCommitFiles(a:bang)
        return
    endif

    let range = s:ParseArgs(a:args)
    let base = s:GetMergeBase(range.right)
    
    call s:SetReviewBaseRef(base)
    
    execute 'G' . a:bang . ' difftool --name-status ' . base . ' ' . range.right
endfunction

augroup Refuge
    autocmd!
    autocmd User FugitiveBlob nnoremap <buffer> dr :<C-U>Gvdiffsplit! refs/refuge/base <CR>
augroup END

" GRCommit: show commits between base and target
command! -bang -nargs=* -complete=customlist,s:CompleteRefs GRCommit
    \ call s:GRCommit(<q-args>, '<bang>')

" GRFiles: show changed files
" - In commit buffer: show files for current commit
" - Otherwise: show files between merge-base and target
command! -bang -nargs=* -complete=customlist,s:CompleteRefs GRFiles
    \ call s:GRFiles(<q-args>, '<bang>')
