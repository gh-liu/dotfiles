if !filereadable(expand("$HOME/.vim/autoload/plug.vim"))
	call system("curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim")
endif

" Sets {{{1
let mapleader=' '

set encoding=utf-8

set backspace=2

set termguicolors

syntax enable

set nu
set rnu

set laststatus=2

set cursorline

set incsearch
set hlsearch

set smartcase
set ignorecase

set scrolloff=3

set foldlevel=9
set nofoldenable

set signcolumn=yes

set clipboard=unnamedplus

set nobackup noswapfile
" }}}

" Remaps {{{1
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

imap <C-e> <END>
imap <C-a> <HOME>

inoremap jj <ESC>

nnoremap <C-q> :q<cr>

cmap <C-e> <END>
cmap <C-a> <HOME>
cmap <C-h> <Left>
cmap <C-j> <Down>
cmap <C-k> <Up>
cmap <C-l> <Right>

vmap < <gv
vmap > >gv
" }}}

" Plugins {{{1
call plug#begin()
if !has('nvim')
    Plug 'rhysd/vim-healthcheck'
endif

Plug 'nordtheme/vim'

Plug 'junegunn/vim-easy-align'

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

Plug 'prabirshrestha/vim-lsp'
Plug 'mattn/vim-lsp-settings'

Plug 'prabirshrestha/asyncomplete.vim'
Plug 'prabirshrestha/asyncomplete-lsp.vim'

Plug 'hrsh7th/vim-vsnip'
Plug 'hrsh7th/vim-vsnip-integ'

Plug 'tpope/vim-repeat'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-sleuth'
Plug 'tpope/vim-abolish'
Plug 'tpope/vim-obsession'
Plug 'tpope/vim-commentary'

Plug 'AndrewRadev/splitjoin.vim'

" Plug 'rhysd/clever-f.vim'
Plug 'justinmk/vim-sneak'

Plug 'junegunn/gv.vim', { 'on': 'GV' }
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'rhysd/conflict-marker.vim'
Plug 'rhysd/git-messenger.vim'

Plug 'LunarWatcher/auto-pairs'

Plug 'mbbill/undotree'

Plug 'wellle/targets.vim'

Plug 'szw/vim-maximizer'

Plug 'machakann/vim-highlightedyank'

Plug 'lilydjwg/colorizer'

call plug#end()
" }}}

colorscheme nord

" fzf {{{2
nnoremap <leader>sf :Files<CR>
nnoremap <leader>sg :Rg<CR>
nnoremap <leader>sb :Buffers<CR>
nnoremap <leader>so :History<CR>
nnoremap <leader>sh :Helptags<CR>
nnoremap <leader>sm :Marks<CR>
nnoremap <leader>;  :Commands<CR>

" }}}

" lsp {{{2
function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
    if exists('+tagfunc') | setlocal tagfunc=lsp#tagfunc | endif

    " setlocal foldmethod=expr
    " setlocal foldexpr=lsp#ui#vim#folding#foldexpr()
    " setlocal foldtext=lsp#ui#vim#folding#foldtext()

    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> gi <plug>(lsp-implementation)
    nmap <buffer> gD <plug>(lsp-type-definition)
    nmap <buffer> <leader>rn <plug>(lsp-rename)
    nmap <buffer> [d <plug>(lsp-previous-diagnostic)
    nmap <buffer> ]d <plug>(lsp-next-diagnostic)
    nmap <buffer> K <plug>(lsp-hover)

    " nnoremap <buffer> <expr><c-f> lsp#scroll(+4)
    " nnoremap <buffer> <expr><c-d> lsp#scroll(-4)
endfunction

augroup lsp_install
    au!
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

if executable('gopls')
    autocmd BufWritePre *.go
        \ call execute('LspDocumentFormatSync') |
        \ call execute('LspCodeActionSync source.organizeImports')
endif


let g:lsp_semantic_enabled = 1
hi Type        guifg=#8FBCBB
hi Class       guifg=#8FBCBB
" hi Enum        guifg=
hi Interface   guifg=#8FBCBB
hi Struct      guifg=#8FBCBB
" hi Parameter   guifg=
hi Variable    guifg=#D8DEE9
" hi Property    guifg=
" hi EnumMember  guifg=
" hi Events      guifg=
hi Function    guifg=#88C0D0
hi Method      guifg=#88C0D0
hi SpecialChar guifg=#D08770
" hi Modifier    guifg=
hi Comment     guifg=#434C5E
hi String      guifg=#A3BE8C
hi Number      guifg=#B48EAD
" hi Regexp      guifg=
hi Operator    guifg=#81A1C1

hi link LspSemanticType          Type
hi link LspSemanticClass         Class
hi link LspSemanticEnum          Enum
hi link LspSemanticInterface     Interface
hi link LspSemanticStruct        Struct
hi link LspSemanticTypeParameter TypeParameter
hi link LspSemanticParameter     Parameter
hi link LspSemanticVariable      Variable
hi link LspSemanticProperty      Property
hi link LspSemanticEnumMember    EnumMember
hi link LspSemanticEvent         Event
hi link LspSemanticFunction      Function
hi link LspSemanticMethod        Method
hi link LspSemanticMacro         Macro
hi link LspSemanticKeyword       Keyword
hi link LspSemanticModifier      Modifier
hi link LspSemanticComment       Comment
hi link LspSemanticString        String
hi link LspSemanticNumber        Number
hi link LspSemanticRegexp        Regexp
hi link LspSemanticOperator      Operator

let g:lsp_inlay_hints_enabled = 1
highlight link lspInlayHintsType Comment
highlight link lspInlayHintsParameter Comment

let g:lsp_diagnostics_virtual_text_enabled=0
let g:lsp_diagnostics_float_cursor=1

augroup lsp_folding
    autocmd!
    autocmd FileType go setlocal
                \ foldmethod=expr
                \ foldexpr=lsp#ui#vim#folding#foldexpr()
                \ foldtext=lsp#ui#vim#folding#foldtext()
augroup end

let g:lsp_settings = {
            \  'gopls': {'initialization_options': {
            \     'semanticTokens': v:true,
            \     'ui.inlayhint.hints': {
            \         'assignVariableTypes': v:true,
            \         'compositeLiteralFields': v:true,
            \         'compositeLiteralTypes': v:true,
            \         'constantValues': v:true,
            \         'functionTypeParameters': v:true,
            \         'parameterNames': v:true,
            \         'rangeVariableTypes': v:true,
            \     },
            \}}
            \}
" }}}

" cmp {{{2
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <expr> <cr>    pumvisible() ? asyncomplete#close_popup() : "\<cr>"

" }}}

" Event {{{1
augroup ft_vim
  autocmd!
  autocmd FileType vim :setl foldmethod=marker
augroup END
" }}}

function! SynStack()
  if !exists("*synstack")
    return
  endif
  echo map(synstack(line('.'), col('.')), 'synIDattr(v:val, "name")')
endfunc
