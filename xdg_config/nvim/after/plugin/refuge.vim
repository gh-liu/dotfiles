" refuge.vim - Review workflow for vim-fugitive (review + fugitive)
" Works with vim-qfugitive for auto diff view
"
" Usage:
"   :GRCommit [base] [target]  - Show commits (default: @..FETCH_HEAD)
"   :GRFiles [base] [target]   - Show changed files (in commit buffer: current commit)
"   :GRWorktree                - Show uncommitted changes (e.g. AI changes)

if exists('g:loaded_refuge') || !exists('*FugitiveGitDir')
    finish
endif
let g:loaded_refuge = 1

" Get or set the diff target
function! s:GetDiffTarget(args) abort
    if len(a:args) > 0
        let g:diff_target = a:args
    endif
    return get(g:, 'diff_target', 'FETCH_HEAD')
endfunction

" Get merge-base using fugitive#Execute
function! s:GetMergeBase(target) abort
    let dir = FugitiveGitDir()
    let result = fugitive#Execute(dir, 'merge-base', '@', a:target)
    return result.exit_status == 0 ? trim(join(result.stdout, '')) : '@'
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
    return filter(sort(heads), 'v:val =~# "^" . a:ArgLead')
endfunction

" Parse args: support 0, 1, or 2 arguments
" 0 args: [@, cached_target]
" 1 arg:  [@, target]
" 2 args: [base, target]
function! s:ParseArgs(args) abort
    let parts = split(a:args)
    if len(parts) == 0
        return ['@', s:GetDiffTarget('')]
    elseif len(parts) == 1
        return ['@', s:GetDiffTarget(parts[0])]
    else
        return [parts[0], parts[1]]
    endif
endfunction

" Get files for current commit if in commit buffer
function! s:GetCommitFiles(bang) abort
    let ftype = get(b:, 'fugitive_type', '')
    if ftype ==# 'commit'
        let commit = fugitive#Object(@%)
        execute 'G' . a:bang . ' difftool --name-status ' . commit . '~' . ' ' . commit
        return 1
    endif
    return 0
endfunction

" GRCommit: show commits between base and target
command! -bang -nargs=* -complete=customlist,s:CompleteRefs GRCommit
    \ let s:range = s:ParseArgs(<q-args>) |
    \ execute 'Gclog<bang> ' . s:range[0] . '..' . s:range[1]

" GRFiles: show changed files
" - In commit buffer: show files for current commit
" - Otherwise: show files between merge-base and target
command! -bang -nargs=* -complete=customlist,s:CompleteRefs GRFiles
    \ if !s:GetCommitFiles('<bang>') |
    \   let s:range = s:ParseArgs(<q-args>) |
    \   let s:base = s:GetMergeBase(s:range[1]) |
    \   execute 'G<bang> difftool --name-status ' . s:base . ' ' . s:range[1] |
    \ endif

" GRWorktree: show uncommitted changes (staged + unstaged)
command! -bang GRWorktree G<bang> difftool --name-status HEAD
