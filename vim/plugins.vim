call plug#begin('~/.vim/plugged')

" View --------{{{
" Theme
Plug 'gruvbox-community/gruvbox'
let g:gruvbox_contrast_dark = 'soft'

" Status Line
Plug 'itchyny/lightline.vim'
if has_key(g:plugs, 'lightline.vim')
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
endif

" Rainbow Parentheses
Plug 'kien/rainbow_parentheses.vim'
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
        \ ['darkmagenta', 'DarkOrchid3'],
        \ ['Darkblue',    'firebrick3'],
        \ ['darkgreen',   'RoyalBlue3'],
        \ ['darkcyan',    'SeaGreen3'],
        \ ['darkred',     'DarkOrchid3'],
        \ ['red',         'firebrick3'],
        \ ]

    let g:rbpt_max = 16
    let g:rbpt_loadcmd_toggle = 0
    autocmd VimEnter * RainbowParenthesesToggle
    autocmd Syntax * RainbowParenthesesLoadRound
    autocmd Syntax * RainbowParenthesesLoadSquare
    autocmd Syntax * RainbowParenthesesLoadBraces
endif

" highlight yank
Plug 'machakann/vim-highlightedyank'
let g:highlightedyank_highlight_duration = 100

" Underlines the word under the cursor
Plug 'itchyny/vim-cursorword'

" Plug 'Yggdroot/indentLine'
if has_key(g:plugs, 'indentLine')
    autocmd! User indentLine doautocmd indentLine Syntax
    let g:indentLine_color_term = 239
    let g:indentLine_color_gui = '#616161'
endif
" }}}

" Edit --------{{{
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-abolish'
" Plug 'arthurxavierx/vim-caser'
Plug 'andrewradev/splitjoin.vim'
if has_key(g:plugs, 'splitjoin.vim')
    nnoremap gss :SplitjoinSplit<cr>
    nnoremap gsj :SplitjoinJoin<cr>
endif
" Comment
Plug 'tpope/vim-commentary'
if has_key(g:plugs, 'vim-commentary')
    " vim-commentary
    autocmd FileType toml setlocal commentstring=#\ %s
    " vim registers <C-/> as <C-_>
    nmap <C-_> gcc
    imap <C-_> <C-O>gcc
    vmap <C-_> gc
endif

" Aligning text
" Plug 'junegunn/vim-easy-align'
if has_key(g:plugs, 'vim-easy-align')
    vmap <Leader>a <Plug>(EasyAlign)
    nmap <Leader>a <Plug>(EasyAlign)
endif

Plug 'bronson/vim-trailing-whitespace', { 'on': 'FixWhitespace' }

Plug 'AndrewRadev/switch.vim'
if has_key(g:plugs, 'switch.vim')
    let g:switch_mapping = '_'
    let g:switch_custom_definitions = [
    \   ['MON', 'TUE', 'WED', 'THU', 'FRI'],
    \   ['ture', 'false']
    \ ]
endif
" }}}

" Nav --------{{{
" Plug 'ludovicchabant/vim-gutentags'
if has_key(g:plugs, 'vim-gutentags')
    let g:gutentags_enabled=0
endif
" Browse the tags of the currentfile
Plug 'majutsushi/tagbar'
if has_key(g:plugs, 'tagbar')
    let g:tagbar_autofocus = 1
    let g:tagbar_position = 'leftabove vertical'
    let g:tagbar_width = 25
    nnoremap T :TagbarToggle<CR>

    " https://github.com/preservim/tagbar/wiki#markdown
    let g:tagbar_type_markdown = {
    \ 'ctagstype'	: 'markdown',
    \ 'kinds'		: [
        \ 'c:chapter:0:1',
        \ 's:section:0:1',
        \ 'S:subsection:0:1',
        \ 't:subsubsection:0:1',
        \ 'T:l4subsection:0:1',
        \ 'u:l5subsection:0:1',
    \ ],
    \ 'sro'			: '""',
    \ 'kind2scope'	: {
        \ 'c' : 'chapter',
        \ 's' : 'section',
        \ 'S' : 'subsection',
        \ 't' : 'subsubsection',
        \ 'T' : 'l4subsection',
    \ },
    \ 'scope2kind'	: {
        \ 'chapter' : 'c',
        \ 'section' : 's',
        \ 'subsection' : 'S',
        \ 'subsubsection' : 't',
        \ 'l4subsection' : 'T',
    \ },
    \ }

" slow
"     let g:tagbar_type_json = {
"     \ 'ctagstype' : 'json',
"     \ 'kinds' : [
"       \ 'o:objects',
"       \ 'a:arrays',
"       \ 'n:numbers',
"       \ 's:strings',
"       \ 'b:booleans',
"       \ 'z:nulls'
"     \ ],
"   \ 'sro' : '.',
"     \ 'scope2kind': {
"     \ 'object': 'o',
"       \ 'array': 'a',
"       \ 'number': 'n',
"       \ 'string': 's',
"       \ 'boolean': 'b',
"       \ 'null': 'z'
"     \ },
"     \ 'kind2scope': {
"     \ 'o': 'object',
"       \ 'a': 'array',
"       \ 'n': 'number',
"       \ 's': 'string',
"       \ 'b': 'boolean',
"       \ 'z': 'null'
"     \ },
"     \ 'sort' : 0
"     \ }
endif

" show marks
Plug 'kshenoy/vim-signature'
if has_key(g:plugs, 'vim-signature')
    let g:SignatureMap = {
        \ 'Leader'             :  "m",
        \ 'PlaceNextMark'      :  "m,",
        \ 'ToggleMarkAtLine'   :  "m.",
        \ 'PurgeMarksAtLine'   :  "m-",
        \ 'DeleteMark'         :  "dm",
        \ 'PurgeMarks'         :  "m<Space>",
        \ 'PurgeMarkers'       :  "m<BS>",
        \ 'GotoNextLineAlpha'  :  "']",
        \ 'GotoPrevLineAlpha'  :  "'[",
        \ 'GotoNextSpotAlpha'  :  "`]",
        \ 'GotoPrevSpotAlpha'  :  "`[",
        \ 'GotoNextLineByPos'  :  "]'",
        \ 'GotoPrevLineByPos'  :  "['",
        \ 'GotoNextSpotByPos'  :  "]`",
        \ 'GotoPrevSpotByPos'  :  "[`",
        \ 'GotoNextMarker'     :  "]-",
        \ 'GotoPrevMarker'     :  "[-",
        \ 'GotoNextMarkerAny'  :  "]=",
        \ 'GotoPrevMarkerAny'  :  "[=",
        \ 'ListBufferMarks'    :  "m/",
        \ 'ListBufferMarkers'  :  "m?"
        \ }
endif

" File Tree
Plug 'tpope/vim-vinegar'
" netrw
" let g:netrw_banner = 1
" let g:netrw_browse_split = 4
" let g:netrw_altv = 1
let g:netrw_liststyle = 3
" let g:netrw_winsize = 25
map <C-n> :Vexplore<CR>

" undotree
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
if has_key(g:plugs, 'undotree')
    let g:undotree_SetFocusWhenToggle = 1
    let g:undotree_WindowLayout = 2
    nnoremap U :UndotreeToggle<CR>
endif

" Bracket maps
" Plug 'tpope/vim-unimpaired'

" Extended "%" matching
Plug 'vim-scripts/matchit.zip'

Plug 't9md/vim-choosewin'
nmap <C-w><C-w> <Plug>(choosewin)

Plug 'easymotion/vim-easymotion'
if has_key(g:plugs, 'vim-easymotion')
    let g:EasyMotion_do_mapping = 0
    let g:EasyMotion_smartcase = 1
    map <Leader><leader>. <Plug>(easymotion-repeat)
    map <Leader><leader>h <Plug>(easymotion-linebackward)
    map <Leader><leader>l <Plug>(easymotion-lineforward)
    map <Leader><Leader>j <Plug>(easymotion-j)
    map <Leader><Leader>k <Plug>(easymotion-k)

    map <Leader><Leader>W <Plug>(easymotion-W) 
    map <Leader><Leader>w <Plug>(easymotion-w) 
    map <Leader><Leader>N <Plug>(easymotion-N)
    map <Leader><Leader>n <Plug>(easymotion-n)
endif
" }}}

" Git --------{{{
Plug 'tpope/vim-fugitive'
nmap <leader>gb :Gblame<CR>
vmap <leader>gb :Gblame<CR>
" nmap <leader>gr :Gread<CR>
" nmap <leader>gw :Gwrite<CR>
" nmap <leader>gd :tabe<CR>:Gdiffsplit<CR>
" nmap <leader>gs :tabe<CR>:Gstatus<CR>
" nmap <leader>gc :Gcommit<CR>
nmap <leader>gl :tabe %<CR>:Glog -- %<CR>
" shows a git diff
" Plug 'airblade/vim-gitgutter', { 'on': 'GitGutterToggle' }
if has_key(g:plugs, 'vim-gitgutter')
    let g:gitgutter_enabled = 0
    nnoremap <leader>gt :GitGutterToggle<CR>
endif
" replacement of gitgutter
Plug 'mhinz/vim-signify', { 'on': 'GitGutterToggle' }
if has_key(g:plugs, 'vim-signify')
    let g:signify_vcs_list = ['git']
    nnoremap <leader>gt :SignifyToggle<CR>
endif
" show the git message
" Plug 'rhysd/git-messenger.vim'
" }}}

" Interact with tmux --------{{{
Plug 'benmills/vimux'
if has_key(g:plugs, 'vimux')
    nnoremap <Leader>vp :VimuxPromptCommand<CR>
    nnoremap <Leader>vc :VimuxCloseRunner<CR>
    nnoremap <Leader>vl :VimuxRunLastCommand<CR>
endif
" }}}

" Search --------{{{
" Plug 'ctrlpvim/ctrlp.vim'
Plug 'dyng/ctrlsf.vim'
if has_key(g:plugs, 'ctrlsf.vim')
    " let g:ctrlsf_default_view_mode = 'compact'
    let g:ctrlsf_auto_focus = {
        \ "at": "start",
        \ }
    nmap     <leader>ff <Plug>CtrlSFPrompt
    vmap     <leader>ff <Plug>CtrlSFVwordPath
    vmap     <leader>fF <Plug>CtrlSFVwordExec
    nmap     <leader>fw <Plug>CtrlSFCwordPath
    nmap     <leader>fW <Plug>CtrlSFCwordExec
    nmap     <leader><leader>f <Plug>CtrlSFPwordExec

    nnoremap <leader>ft :CtrlSFToggle<CR>
    nnoremap <silent> <leader>fj :CtrlSFFocus<CR>
endif
Plug 'junegunn/fzf',        { 'do': './install --all' }
Plug 'junegunn/fzf.vim'
let g:fzf_layout = { 'down': '~20%' }
nmap <C-p> :Files<cr>
imap <C-p> <esc>:<C-u>Files<cr>
" Plug 'mileszs/ack.vim'
" }}}

" coc.nvim --------{{{
Plug 'neoclide/coc.nvim', {'branch': 'release'}
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

    " Make <tab> used for trigger snippet expand and jump like VSCode.
    let g:coc_snippet_next = '<tab>'

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
      \'coc-snippets',
      \'coc-pairs',
      \'coc-yaml',
      \'coc-json',
      \'coc-vimlsp',
      \'coc-go'
      \]

    augroup coc-conf
      autocmd!
      " goto code navigation.
      autocmd VimEnter * nmap <silent> gd <Plug>(coc-definition)
      autocmd VimEnter * nmap <silent> gy <Plug>(coc-type-definition)
      autocmd VimEnter * nmap <silent> gi <Plug>(coc-implementation)
      autocmd VimEnter * nmap <silent> gr <Plug>(coc-references)

      autocmd VimEnter * nmap <silent> <leader>rn <Plug>(coc-rename)
      autocmd VimEnter * nmap <silent> <leader>fc <Plug>(coc-fix-current)

      autocmd VimEnter * nmap <silent> [d <Plug>(coc-diagnostic-prev)
      autocmd VimEnter * nmap <silent> ]d <Plug>(coc-diagnostic-next)

    "   autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
    augroup END

    " Add `:Format` command to format current buffer.
    command! -nargs=0 Format :call CocAction('format')
    " Add some commands for Go
    command! -nargs=0 GoGenTestFile :call CocAction('runCommand', 'go.test.generate.file')
    command! -nargs=0 GoGenTestFunc :call CocAction('runCommand', 'go.test.generate.function')
    command! -nargs=0 GoGenTestExpo :call CocAction('runCommand', 'go.test.generate.exported')
    command! -nargs=0 GoTestToggle  :call CocAction('runCommand', 'go.test.toggle')

    " Mappings for CoCList
    " Show all diagnostics.
    nnoremap <silent><nowait> <space>d  :<C-u>CocList --normal diagnostics<cr>
    " Manage extensions.
    nnoremap <silent><nowait> <space>e  :<C-u>CocList --normal extensions<cr>
    " Show commands.
    nnoremap <silent><nowait> <space>c  :<C-u>CocList commands<cr>
    " Find symbol of current document.
    nnoremap <silent><nowait> <space>o  :<C-u>CocList --normal outline<cr>
    " Search workspace symbols.
    nnoremap <silent><nowait> <space>s  :<C-u>CocList -I symbols<cr>
    " open yank list
    " nnoremap <silent> <space>y  :<C-u>CocList -A --normal yank<cr>
    " Do default action for next item.
    nnoremap <silent><nowait> <space>j  :<C-u>CocNext<CR>
    " Do default action for previous item.
    nnoremap <silent><nowait> <space>k  :<C-u>CocPrev<CR>
    " Resume latest coc list.
    nnoremap <silent><nowait> <space>p  :<C-u>CocListResume<CR>

    " plugs settings:
    " coc-explorer
    " map <leader><leader>e :CocCommand explorer<CR>
endif
" }}}

" lang --------{{{
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
if has_key(g:plugs, 'vim-go')
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
    let g:go_debug_preserve_layout = 1
    let g:go_highlight_debug = 0
    " complete by coc.nvim
    let g:go_code_completion_enabled = 0
    let g:go_test_show_name = 1

    let g:go_debug_mappings = {
      \ '(go-debug-stepout)':    {'key': '<F6>'},
      \ '(go-debug-step)':       {'key': '<F7>'},
      \ '(go-debug-next)':       {'key': '<F8>'},
      \ '(go-debug-continue)':   {'key': '<F9>'},
      \ '(go-debug-print)':      {'key': '<F10>'},
      \ }
    let g:go_debug_windows = {
              \ 'vars':       'leftabove 30vnew',
              \ 'stack':      'leftabove 20new',
              \ 'goroutines': 'leftabove 10new',
              \ 'out':        'botright  5new',
    \ }

    augroup vim-go-conf
        autocmd!
        " create custom mappings for Go files
        " autocmd FileType go nmap <silent> <leader>tt  <Plug>(go-test)
        " autocmd FileType go nmap <silent> <leader>tf <Plug>(go-test-func)
        " autocmd FileType go nmap <silent> <leader>cr <Plug>(go-coverage-toggle)
        " autocmd FileType go nmap <silent> <leader>ii <Plug>(go-info)
        " autocmd FileType go nmap <silent> <leader>i  <Plug>(go-implements)
        autocmd FileType go nmap <silent> <leader>d  <Plug>(go-describe)
        " autocmd FileType go nmap <silent> <leader>d  <Plug>(go-def)
        " autocmd FileType go nmap <silent> <leader>p  <Plug>(go-def-pop)

        autocmd FileType go nmap <silent> <leader>b   :GoDebugBreakpoint<cr>

        autocmd FileType go nmap <silent> <leader>cc <Plug>(go-callers)
        autocmd FileType go nmap <silent> <leader>cs <Plug>(go-callstack)

        autocmd FileType go nmap <silent> <Leader>td <Plug>(go-def-tab)
        autocmd Filetype go
            \  command! -bang A call go#alternate#Switch(<bang>0, 'edit')
            \| command! -bang AV call go#alternate#Switch(<bang>0, 'vsplit')
            \| command! -bang AS call go#alternate#Switch(<bang>0, 'split')
    augroup END

endif
" Plug 'rust-lang/rust.vim'

" Plug 'SirVer/ultisnips'

Plug 'aklt/plantuml-syntax'
if executable('java')
  Plug 'scrooloose/vim-slumlord'
endif

" Plug 'cespare/vim-toml'
" Plug 'stephpy/vim-yaml'
Plug 'uarun/vim-protobuf'
" Plug 'elzr/vim-json', {'for' : 'json'}
Plug 'ekalinin/Dockerfile.vim', {'for' : 'Dockerfile'}

" Markdown
Plug 'godlygeek/tabular'
Plug 'plasticboy/vim-markdown'
let g:vim_markdown_folding_disabled = 1
Plug 'iamcco/markdown-preview.nvim', { 'do': ':call mkdp#util#install()', 'for': 'markdown', 'on': 'MarkdownPreview' }
Plug 'mzlogin/vim-markdown-toc'
let g:vmt_fence_text = 'TOC'
let g:vmt_fence_closing_text = '/TOC'






" }}}


" text object --------{{{
" Plug 'kana/vim-textobj-user'
" Plug 'kana/vim-textobj-line'
" Plug 'kana/vim-textobj-entire'
" Plug 'kana/vim-textobj-indent'
" }}}

" other tools --------{{{
" Show keymaps begin with <leader>
" Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }
if has_key(g:plugs, 'vim-which-key')
    nnoremap <silent> <leader> :WhichKey ','<CR>
    set timeoutlen=360
endif

" Plug 'tyru/open-browser.vim'
" let g:netrw_nogx = 1 " disable netrw's gx mapping.
" nmap gx <Plug>(openbrowser-smart-search)
" vmap gx <Plug>(openbrowser-smart-search)

" Vim start up time debug (figure out which script is slow)
" Plug 'tweekmonster/startuptime.vim'

Plug 'szw/vim-smartclose'
let g:smartclose_default_mapping_key = '<leader><leader>c'

" rename the buffer
Plug 'danro/rename.vim'

" vscode's task system
" Plug 'skywind3000/asynctasks.vim'
" Plug 'skywind3000/asyncrun.vim'
" let g:asyncrun_open = 6

" Plug 'puremourning/vimspector'

" Plug 'tmux-plugins/vim-tmux'

" Plug 'vim-scripts/YankRing.vim'
" Plug 'christoomey/vim-tmux-navigator'
" Plug 'dkarter/bullets.vim'

" for making Vim plugins
" Plug 'tpope/vim-scriptease'
" Plug 'junegunn/vader.vim'

" Plug 'ruanyl/vim-gh-line'

" }}}
call plug#end()
