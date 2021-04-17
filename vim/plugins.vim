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
" Plug 'preservim/nerdtree'
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

" NerdTree 
if has_key(g:plugs, 'nerdtree') 
augroup nerdtree_settings
  autocmd!
  " NERDDTree快捷键
  map <C-n> :NERDTreeToggle<CR>
  " nnoremap <leader>t :NERDTreeToggle<CR>
  nnoremap <leader>d :NERDTreeFind<CR>
  " 是否显示隐藏文件
  let NERDTreeShowHidden=1
  " 设置宽度
  let NERDTreeWinSize=30
  " 在终端启动vim时，共享NERDTree
  let g:nerdtree_tabs_open_on_console_startup=1
  " 忽略以下文件的显示
  " let NERDTreeIgnore=['\.pyc','\~$',
  "             \ '\.swp',
  "             \ '\.o',
  "             \ '.DS_Store',
  "             \ '\.orig$',
  "             \ '@neomake_',
  "             \ '.coverage.',
  "             \ '__pycache__$[[dir]]',
  "             \ '.pytest_cache$[[dir]]',
  "             \ '.git$[[dir]]',
  "             \ '.idea[[dir]]',
  "             \ '.vscode[[dir]]',
  "             \ 'htmlcov[[dir]]',
  "             \ 'test-reports[[dir]]',
  "             \ '.egg-info$[[dir]]']
  " 显示书签列表
  let NERDTreeShowBookmarks=1
  " 改变nerdtree的箭头
  " let g:NERDTreeDirArrowExpandable = '?'
  " let g:NERDTreeDirArrowCollapsible = '?'
  " vim不指定具体文件打开时，自动使用nerdtree
  autocmd StdinReadPre * let s:std_in=1
  autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree |endif

  " 当vim打开一个目录时，nerdtree自动使用
  autocmd StdinReadPre * let s:std_in=1
  autocmd VimEnter * if argc() == 1 && isdirectory(argv()[0]) && !exists("s:std_in") | exe 'NERDTree' argv()[0] | wincmd p | ene | endif
  " 打开新的窗口，focus在buffer里而不是NerdTree里
  autocmd VimEnter * :wincmd l

  " 当vim中没有其他文件，值剩下nerdtree的时候，自动关闭窗口
  autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif
augroup END
endif

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
nnoremap <Leader>ri :VimuxPromptCommand<CR>
nnoremap <Leader>rc :VimuxCloseRunner<CR>
nnoremap <Leader>rl :VimuxRunLastCommand<CR>

" tagbar
nnoremap <F2> :TagbarToggle<CR>

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
    \'coc-json',
    \'coc-toml', 
    \'coc-yaml',
    \'coc-go'
    \]

  augroup coc-config
    autocmd!
    autocmd VimEnter * nmap <silent> <leader>gd <Plug>(coc-definition)
    autocmd VimEnter * nmap <silent> <leader>gi <Plug>(coc-implementation)
    autocmd VimEnter * nmap <silent> <leader>gr <Plug>(coc-references)
    
    autocmd VimEnter * nmap <silent> <leader>rn <Plug>(coc-rename)
  augroup END

  " Add `:Format` command to format current buffer.
  command! -nargs=0 Format :call CocAction('format')

  map <leader>e :CocCommand explorer<CR>
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
  \ '(go-debug-breakpoint)': {'key': '<F6>'},
  \ '(go-debug-step)':       {'key': '<F7>'},
  \ '(go-debug-next)':       {'key': '<F8>'},
  \ '(go-debug-continue)':   {'key': '<F9>'},
  \ '(go-debug-print)':      {'key': '<F10>'},
  \ '(go-debug-halt)':       {'key': '<F11>'},
  \ }


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

autocmd FileType toml setlocal commentstring=#\ %s