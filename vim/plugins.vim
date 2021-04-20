" >>>>>> Plugins 

call plug#begin('~/.vim/plugged')

" Theme 
Plug 'morhetz/gruvbox'

" Status Line 
Plug 'itchyny/lightline.vim'

" Rainbow Parentheses 
Plug 'kien/rainbow_parentheses.vim'

" Underlines the word under the cursor 
Plug 'itchyny/vim-cursorword'

" File Tree 
Plug 'tpope/vim-vinegar'

" Show keymaps begin with <leader> 
Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }

" Git 
Plug 'tpope/vim-fugitive'
" shows a git diff 
Plug 'airblade/vim-gitgutter'
" show the git message 
Plug 'rhysd/git-messenger.vim'

" Interact with tmux 
Plug 'benmills/vimux'

" Vim start up time debug (figure out which script is slow) 
Plug 'tweekmonster/startuptime.vim'

" Browse the tags of the current file
Plug 'majutsushi/tagbar'

" Edit
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'

" Pairs
" Plug 'jiangmiao/auto-pairs'

" Comment 
" Plug 'preservim/nerdcommenter'
" Plug 'tomtom/tcomment_vim'
Plug 'tpope/vim-commentary'

" Aligning text 
Plug 'godlygeek/tabular'

" Search 
Plug 'ctrlpvim/ctrlp.vim' 
Plug 'dyng/ctrlsf.vim'
Plug 'junegunn/fzf',        { 'do': './install --all' }
Plug 'junegunn/fzf.vim'

" Bracket maps
Plug 'tpope/vim-unimpaired'

" Language 
Plug 'neoclide/coc.nvim', {'branch': 'release', 'do': { -> coc#util#install() }}
" Plug 'SirVer/ultisnips'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
" Plug 'rust-lang/rust.vim'

" Markdown 
Plug 'plasticboy/vim-markdown'
let g:vim_markdown_folding_disabled = 1
" markdown preview 
Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}

call plug#end()


" >>>>>> Plugins Setting 

" vim-plug
command! PU PlugUpdate | PlugUpgrade

" gruvbox
let g:gruvbox_contrast_dark = 'soft'

" lightline.vim 
let g:lightline = {
      \ 'colorscheme': 'powerline',
      \ 'active': {
      \   'left': [ [ 'mode', 'paste' ],
      \             [ 'gitbranch', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component_function': {
      \   'gitbranch': 'FugitiveHead'
      \ },
      \ }

" rainbow_parentheses.vim 
if has_key(g:plugs, 'rainbow_parentheses.vim')
  let g:rbpt_colorpairs = [
    \ ['brown',       'RoyalBlue3'],
    \ ['Darkblue',    'SeaGreen3'],
    \ ['darkgray',    'DarkOrchid3'],
    \ ['darkgreen',   'firebrick3'],
    \ ['darkcyan',    'RoyalBlue3'],
    \ ['darkred',     'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['brown',       'firebrick3'],
    \ ['gray',        'RoyalBlue3'],
    \ ['black',       'SeaGreen3'],
    \ ['darkmagenta', 'DarkOrchid3'],
    \ ['Darkblue',    'firebrick3'],
    \ ['darkgreen',   'RoyalBlue3'],
    \ ['darkcyan',    'SeaGreen3'],
    \ ['darkred',     'DarkOrchid3'],
    \ ['red',         'firebrick3'],
    \ ]
  let g:rbpt_max = 16
endif

" vim-which-key
if has_key(g:plugs, 'vim-which-key')
  nnoremap <silent> <leader> :WhichKey ','<CR>
  set timeoutlen=500
endif

" vimux
nnoremap <Leader>tp :VimuxPromptCommand<CR>
nnoremap <Leader>tc :VimuxCloseRunner<CR>
nnoremap <Leader>tl :VimuxRunLastCommand<CR>

" tagbar
nnoremap <leader>lt :TagbarToggle<CR>

"  coc.nvim 
if has_key(g:plugs, 'coc.nvim')
  " Use <cr> to confirm completion
  inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
  " To make <cr> select the first completion item and confirm the completion when no item has been selected
  inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm() : "\<C-g>u\<CR>"

  " Use <tab> for trigger completion and navigate to the next complete item
  function! s:check_back_space() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1]  =~# '\s'
  endfunction
  inoremap <silent><expr> <TAB>
        \ pumvisible() ? "\<C-n>" :
        \ <SID>check_back_space() ? "\<TAB>" :
        \ coc#refresh()
  " Use <S-Tab> navigate to the previous complete item
  inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

  " Use K to show documentation
  function! s:show_documentation()
    if (index(['vim', 'help'], &filetype) >= 0)
      execute 'h' expand('<cword>')
    else
      call CocAction('doHover')
    endif
  endfunction
  nnoremap <silent> K :call <SID>show_documentation()<CR>

  " Extensions for CoC
  let g:coc_global_extensions = [
    \'coc-explorer',
    \'coc-snippets',
    \'coc-pairs',
    \'coc-json',
    \'coc-toml', 
    \'coc-yaml',
    \'coc-sh',
    \'coc-go'
    \]

  augroup coc-config
    autocmd!
    " autocmd VimEnter * nmap <silent> <leader>jd <Plug>(coc-definition)
    " autocmd VimEnter * nmap <silent> <leader>gi <Plug>(coc-implementation)
    " autocmd VimEnter * nmap <silent> <leader>gr <Plug>(coc-references)
    
    " autocmd VimEnter * nmap <silent> <leader>rn <Plug>(coc-rename)

    autocmd VimEnter * nmap <silent> [d <Plug>(coc-diagnostic-prev)
    autocmd VimEnter * nmap <silent> ]d <Plug>(coc-diagnostic-next)
  augroup END

  " Add `:Format` command to format current buffer.
  command! -nargs=0 Format :call CocAction('format')

  map <leader>ee :CocCommand explorer<CR>
endif

" vim-go 
" Go syntax highlighting
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_function_calls = 1
let g:go_highlight_extra_types = 1
let g:go_highlight_operators = 1
" Status line types/signatures
let g:go_auto_type_info = 1
" disable K
let g:go_doc_keywordprg_enabled = 0
let g:go_debug_mappings = {
  \ '(go-debug-step)':       {'key': '<leader>ds'},
  \ '(go-debug-stepout)':    {'key': '<leader>do'},
  \ '(go-debug-next)':       {'key': '<leader>dn'},
  \ '(go-debug-continue)':   {'key': '<leader>dc'},
  \ '(go-debug-print)':      {'key': '<leader>dp'},
  \ '(go-debug-halt)':       {'key': '<leader>dh'},
  \ }

augroup golang
    let g:tagbar_type_go = {
      \ 'ctagstype' : 'go',
      \ 'kinds'     : [
        \ 'p:package',
        \ 'i:imports:1',
        \ 'c:constants',
        \ 'v:variables',
        \ 't:types',
        \ 'n:interfaces',
        \ 'w:fields',
        \ 'e:embedded',
        \ 'm:methods',
        \ 'r:constructor',
        \ 'f:functions'
      \ ],
      \ 'sro' : '.',
      \ 'kind2scope' : {
        \ 't' : 'ctype',
        \ 'n' : 'ntype'
      \ },
      \ 'scope2kind' : {
        \ 'ctype' : 't',
        \ 'ntype' : 'n'
      \ },
      \ 'ctagsbin'  : 'gotags',
      \ 'ctagsargs' : '-sort -silent'
    \ }

    " create custom mappings for Go files
    " autocmd BufEnter *.go nmap <leader>t  <Plug>(go-test)
    " autocmd BufEnter *.go nmap <leader>tt <Plug>(go-test-func)
    " autocmd BufEnter *.go nmap <leader>c  <Plug>(go-coverage-toggle)
    " autocmd BufEnter *.go nmap <leader>ii <Plug>(go-info)
    autocmd BufEnter *.go nmap <leader>li  <Plug>(go-implements)
    autocmd BufEnter *.go nmap <leader>ld  <Plug>(go-describe)
    autocmd BufEnter *.go nmap <leader>lr  <Plug>(go-def)

    autocmd BufEnter *.go nmap <leader>rn  <Plug>(go-rename)

    autocmd BufEnter *.go nmap <leader>db  :GoDebugBreakpoint<cr>
    autocmd BufEnter *.go nmap <leader>ds  :GoDebugStart
    autocmd BufEnter *.go nmap <leader>dq  <Plug>(go-debug-stop)

    autocmd BufEnter *.go nmap <leader>cc  <Plug>(go-callers)
    autocmd BufEnter *.go nmap <leader>cs  <Plug>(go-callstack)
augroup END

" CtrlSF.vim
" let g:ctrlsf_default_view_mode = 'compact'
let g:ctrlsf_auto_focus = {
    \ "at": "start",
    \ }
nmap     <leader>ff <Plug>CtrlSFPrompt
vmap     <leader>ff <Plug>CtrlSFVwordPath
vmap     <leader>fF <Plug>CtrlSFVwordExec
nmap     <leader>fn <Plug>CtrlSFCwordPath
nnoremap <leader>fo :CtrlSFOpen<CR>
nnoremap <leader>ft :CtrlSFToggle<CR>
inoremap <leader>ft <Esc>:CtrlSFToggle<CR>
nnoremap <silent> <leader>fj :CtrlSFFocus<CR>


" NERDCommenter
" let g:NERDCreateDefaultMappings = 0
" map <leader>cc  <plug>NERDCommenterToggle

" netrw
let g:netrw_liststyle = 3
let g:netrw_winsize = 25
map <C-n> :Lexplore<CR>

" vim-commentary
autocmd FileType toml setlocal commentstring=#\ %s
" vim registers <C-/> as <C-_>
nmap <C-_> gcc
imap <C-_> <C-O>gcc

" fugitive.vim mappings
nmap <leader>gb :Gblame<CR>
nmap <leader>gr :Gread<CR>
nmap <leader>gw :Gwrite<CR>
nmap <leader>gd :tabe<CR>:Gdiffsplit<CR>
nmap <leader>gs :tabe<CR>:Gstatus<CR>
nmap <leader>gc :Gcommit<CR>
nmap <leader>gl :tabe %<CR>:Glog -- %<CR>