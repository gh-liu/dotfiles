call plug#begin('~/.vim/plugged')

" == Color == {{{1
" == Theme == {{{2
Plug 'gruvbox-community/gruvbox'
  let g:gruvbox_contrast_dark = 'hard'
Plug 'joshdick/onedark.vim'

" == Status Line == {{{2
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

" == Rainbow Parentheses == {{{2
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

" == Hightligh Yank == {{{2
Plug 'machakann/vim-highlightedyank'
  let g:highlightedyank_highlight_duration = 100

" == Underlines the word under the cursor == {{{2
Plug 'itchyny/vim-cursorword'

" == Marks == {{{2
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

" == Show Hex Colors == {{{2
if executable("go")
    Plug 'rrethy/vim-hexokinase', { 'do': 'make hexokinase','on': ['HexokinaseToggle']}
    set termguicolors
  let g:Hexokinase_highlighters = ['background']
endif

" == Indent Line == {{{2
" Plug 'Yggdroot/indentLine'
" if has_key(g:plugs, 'indentLine')
"     autocmd! User indentLine doautocmd indentLine Syntax
"   let g:indentLine_color_term = 239
"   let g:indentLine_color_gui = '#616161'
" endif

" == Edit == {{{1
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
if has_key(g:plugs, 'vim-commentary')
    autocmd FileType toml setlocal commentstring=#\ %s
  " vim registers <C-/> as <C-_>
    nmap <C-_> gcc
    imap <C-_> <C-O>gcc
    vmap <C-_> gc
endif
Plug 'arthurxavierx/vim-caser'
  let g:caser_prefix = 'cr'
Plug 'andrewradev/splitjoin.vim'
if has_key(g:plugs, 'splitjoin.vim')
    nnoremap gss :SplitjoinSplit<cr>
    nnoremap gsj :SplitjoinJoin<cr>
endif

Plug 'bronson/vim-trailing-whitespace', { 'on': 'FixWhitespace' }

" Aligning text
" Plug 'junegunn/vim-easy-align'
" if has_key(g:plugs, 'vim-easy-align')
"     vmap <Leader>a <Plug>(EasyAlign)
"     nmap <Leader>a <Plug>(EasyAlign)
" endif
" Plug 'mg979/vim-visual-multi', {'branch': 'master'}
" Plug 'AndrewRadev/switch.vim'
" if has_key(g:plugs, 'switch.vim')
"   let g:switch_mapping = '_'
"   let g:switch_custom_definitions = [
"     \   ['MON', 'TUE', 'WED', 'THU', 'FRI'],
"     \   ['ture', 'false']
"     \ ]
" endif

" == Move == {{{1
" Extended "%" matching
Plug 'benjifisher/matchit.zip'

" text object 
" Plug 'kana/vim-textobj-user'
" Plug 'kana/vim-textobj-line'
" Plug 'kana/vim-textobj-entire'
" Plug 'kana/vim-textobj-indent'

" Plug 'easymotion/vim-easymotion'
" if has_key(g:plugs, 'vim-easymotion')
"   let g:EasyMotion_do_mapping = 0
"   let g:EasyMotion_smartcase = 1
"     map <Leader><leader>. <Plug>(easymotion-repeat)
"     map <Leader><leader>h <Plug>(easymotion-linebackward)
"     map <Leader><leader>l <Plug>(easymotion-lineforward)
"     map <Leader><Leader>j <Plug>(easymotion-j)
"     map <Leader><Leader>k <Plug>(easymotion-k)

"     map <Leader><Leader>W <Plug>(easymotion-W) 
"     map <Leader><Leader>w <Plug>(easymotion-w) 
"     map <Leader><Leader>N <Plug>(easymotion-N)
"     map <Leader><Leader>n <Plug>(easymotion-n)
" endif

" == Search == {{{1
" Plug 'ctrlpvim/ctrlp.vim'
Plug 'dyng/ctrlsf.vim'
if has_key(g:plugs, 'ctrlsf.vim')
  " let g:ctrlsf_default_view_mode = 'compact'
  let g:ctrlsf_auto_focus = {
        \ "at": "start",
        \ }
    nnoremap   <leader>ff <Plug>CtrlSFPrompt
    vnoremap   <leader>ff <Plug>CtrlSFVwordPath
    vnoremap   <leader>fF <Plug>CtrlSFVwordExec
    nnoremap   <leader>fw <Plug>CtrlSFCwordPath
    nnoremap   <leader>fW <Plug>CtrlSFCwordExec
    nnoremap   <leader>ft :CtrlSFToggle<CR>
endif
Plug 'junegunn/fzf',        { 'do': './install --all' }
Plug 'junegunn/fzf.vim'
  let g:fzf_layout = { 'down': '~20%' }
nmap <C-p> :Files<cr>
imap <C-p> <esc>:<C-u>Files<cr>
" Plug 'mileszs/ack.vim'

" == COC == {{{
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
  " inoremap <silent><expr> <TAB>
  "       \ pumvisible() ? "\<C-n>" :
  "       \ <SID>check_back_space() ? "\<TAB>" :
  "       \ coc#refresh()
    inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ coc#expandableOrJumpable() ? "\<C-r>=coc#rpc#request('doKeymap', ['snippets-expand-jump',''])\<CR>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
  " Use <S-Tab> navigate to the previous complete item
    inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

  " Make <tab> used for trigger completion, completion confirm, snippet expand and jump like VSCode.
  " https://github.com/neoclide/coc-snippets
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
      \'coc-go',
      \'coc-vimlsp'
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
    " command! -nargs=0 Format :call CocAction('format')
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
    nnoremap <silent><nowait> <space>p :<C-u>CocListResume<CR>

  " plugs settings:
  " coc-explorer
  " map <leader><leader>e :CocCommand explorer<CR>
endif
" }}}

" == Nav == {{{1
" == Tag == {{{2
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

"   let g:tagbar_type_json = {
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
" Plug 'ludovicchabant/vim-gutentags'
" if has_key(g:plugs, 'vim-gutentags')
"   let g:gutentags_enabled=0
" endif

" == netrw == {{{2
Plug 'tpope/vim-vinegar'
" netrw
"   let g:netrw_banner = 1
"   let g:netrw_browse_split = 4
"   let g:netrw_altv = 1
  let g:netrw_liststyle = 3
"   let g:netrw_winsize = 25
map <C-n> :Vexplore<CR>

" == UndoTree == {{{2
Plug 'mbbill/undotree', { 'on': 'UndotreeToggle' }
if has_key(g:plugs, 'undotree')
  let g:undotree_SetFocusWhenToggle = 1
  let g:undotree_WindowLayout = 2
    nnoremap U :UndotreeToggle<CR>
endif

" == Choose Windows == {{{2
" Plug 't9md/vim-choosewin'
" nmap <C-w><C-w> <Plug>(choosewin)


" == Git == {{{1
" Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-fugitive'
if has_key(g:plugs, 'vim-fugitive')
    nmap <leader>gb :Gblame<CR>
    vmap <leader>gb :Gblame<CR>
    nmap <leader>gl :tabe %<CR>:Glog -- %<CR>
endif
" shows a git diff
Plug 'mhinz/vim-signify'
if has_key(g:plugs, 'vim-signify')
  let g:signify_vcs_list = ['git']
    nnoremap <leader>gt :SignifyToggle<CR>
    nnoremap <leader>gd :SignifyHunkDiff<CR>
endif
" show the git message
" Plug 'rhysd/git-messenger.vim'

" == Tmux == {{{1
Plug 'benmills/vimux'
if has_key(g:plugs, 'vimux')
    nnoremap <Leader>vp :VimuxPromptCommand<CR>
    nnoremap <Leader>vc :VimuxCloseRunner<CR>
    nnoremap <Leader>vl :VimuxRunLastCommand<CR>
endif
" Plug 'tmux-plugins/vim-tmux'
" Plug 'christoomey/vim-tmux-navigator'

" == Move == {{{1
" Extended "%" matching
Plug 'benjifisher/matchit.zip'

" text object 
" Plug 'kana/vim-textobj-user'
" Plug 'kana/vim-textobj-line'
" Plug 'kana/vim-textobj-entire'
" Plug 'kana/vim-textobj-indent'

" Plug 'easymotion/vim-easymotion'
" if has_key(g:plugs, 'vim-easymotion')
"   let g:EasyMotion_do_mapping = 0
"   let g:EasyMotion_smartcase = 1
"     map <Leader><leader>. <Plug>(easymotion-repeat)
"     map <Leader><leader>h <Plug>(easymotion-linebackward)
"     map <Leader><leader>l <Plug>(easymotion-lineforward)
"     map <Leader><Leader>j <Plug>(easymotion-j)
"     map <Leader><Leader>k <Plug>(easymotion-k)

"     map <Leader><Leader>W <Plug>(easymotion-W) 
"     map <Leader><Leader>w <Plug>(easymotion-w) 
"     map <Leader><Leader>N <Plug>(easymotion-N)
"     map <Leader><Leader>n <Plug>(easymotion-n)
" endif

" == Lang == {{{1
" == Snippets  == {{{2
" Plug 'SirVer/ultisnips'

" == GO == {{{2
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
    "create custom mappings for Go files
    "autocmd FileType go nmap <silent> <leader>tt  <Plug>(go-test)
    "autocmd FileType go nmap <silent> <leader>tf <Plug>(go-test-func)
    "autocmd FileType go nmap <silent> <leader>cr <Plug>(go-coverage-toggle)
    autocmd FileType go nmap <silent> <leader>d  <Plug>(go-describe)

    autocmd FileType go nmap <silent> <leader>b   :GoDebugBreakpoint<cr>

    autocmd FileType go nmap <silent> <leader><leader>b :<C-u>call <SID>build_go_files()<CR>

    autocmd FileType go nmap <silent> <Leader>td <Plug>(go-def-tab)
    " autocmd Filetype go
    "         \  command! -bang A call go#alternate#Switch(<bang>0, 'edit')
    "         \| command! -bang AV call go#alternate#Switch(<bang>0, 'vsplit')
    "         \| command! -bang AS call go#alternate#Switch(<bang>0, 'split')

    autocmd BufEnter *.go silent exe "GoGuruScope " . go#package#ImportPath() . "..."
  augroup END

  " run :GoBuild or :GoTestCompile based on the go file
  function! s:build_go_files()
    let l:file = expand('%')
    if l:file =~# '^\f\+_test\.go$'
        call go#test#Test(0, 1)
    elseif l:file =~# '^\f\+\.go$'
        call go#cmd#Build(0)
    endif
  endfunction

endif

" == Rust == {{{2
" Plug 'rust-lang/rust.vim'

" == PlantUML == {{{
Plug 'aklt/plantuml-syntax'
if executable('java')
  Plug 'scrooloose/vim-slumlord'
endif

" == Toml Yaml Json Protobuf Dockerfile == {{{2
" Plug 'cespare/vim-toml'
" Plug 'stephpy/vim-yaml'
" Plug 'elzr/vim-json', {'for' : 'json'}
Plug 'uarun/vim-protobuf'
Plug 'ekalinin/Dockerfile.vim', {'for' : 'Dockerfile'}

" == Markdown == {{{2
Plug 'godlygeek/tabular'
Plug 'plasticboy/vim-markdown'
  let g:vim_markdown_folding_disabled = 1
Plug 'iamcco/markdown-preview.nvim', { 'do': ':call mkdp#util#install()', 'for': 'markdown', 'on': 'MarkdownPreview' }
Plug 'mzlogin/vim-markdown-toc'
  let g:vmt_fence_text = 'TOC'
  let g:vmt_fence_closing_text = '/TOC'


" == Misc == {{{1
" Show keymaps begin with <leader>
Plug 'liuchengxu/vim-which-key', { 'on': ['WhichKey', 'WhichKey!'] }
if has_key(g:plugs, 'vim-which-key')
  nnoremap <silent> <leader> :WhichKey ','<CR>
  set timeoutlen=360
endif

Plug 'szw/vim-smartclose'
if has_key(g:plugs, 'vim-smartclose')
  let g:smartclose_default_mapping_key = '<leader>c'
  nnoremap <silent><leader>q :SmartClose<CR>
endif

" Vim sugar for the UNIX shell commands 
Plug 'tpope/vim-eunuch'

" for making Vim plugins
Plug 'tpope/vim-scriptease'
" Plug 'junegunn/vader.vim'

" vscode's task system
" Plug 'skywind3000/asynctasks.vim'
" Plug 'skywind3000/asyncrun.vim'
"   let g:asyncrun_open = 6

" Plug 'ruanyl/vim-gh-line'

" LSP and Complete
" Plug 'prabirshrestha/vim-lsp'
" Plug 'mattn/vim-lsp-settings'
" Plug 'prabirshrestha/asyncomplete.vim'
" Plug 'prabirshrestha/asyncomplete-lsp.vim'

" Plug 'chrisbra/unicode.vim', {'on': ['UnicodeName', 'UnicodeTable']}
"
" Plug 'tyru/open-browser.vim'
"   let g:netrw_nogx = 1 " disable netrw's gx mapping.
"   nmap gx <Plug>(openbrowser-smart-search)
"   vmap gx <Plug>(openbrowser-smart-search)

call plug#end()
