" BASIC CONFIG --------{{{
" With a map leader it's possible to do extra key combinations
let mapleader=','
" Set utf8 as standard encoding and en_US as the standard language
set encoding=utf8
set fileencodings=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
" Set to auto read when a file is changed from the outside
set autoread
" be iMproved
set nocompatible 
" For regular expressions turn magic on
set magic
" Sets how many lines of history VIM has to remember
set history=5000

" Disable the use of the mouse
set mouse-=a
" Always show the status line
set laststatus=2
" Highlight Cursor
set cursorline
set cursorcolumn
" Ignore case when searching
set ignorecase
" Highlight search results
set hlsearch
set incsearch
" 1 tab == 4 spaces
set shiftwidth=4
set tabstop=4
" Use spaces instead of tabs
set expandtab
" Be smart when using tabs ;)
set smarttab
" Auto indent
set autoindent
" Smart indent
set smartindent
" Set number
set number
set relativenumber
" Set 10 lines under the cursor - when moving vertically using j/k
set so=10
" show the cursor position all the time
set ruler
" Turn on the wild menu, complete the command
set wildmenu
" Height of the command bar
set cmdheight=2
" Automatically save before :next, :make etc.
set autowrite 

" set complete-=i
set pumheight=10             " Completion window max size
set completeopt=longest,menu

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

" Enable syntax highlighting
syntax enable 
" Enable 256 colors palette in Gnome Terminal
if $COLORTERM == 'gnome-terminal'
    set t_Co=256
endif
set background=dark
" Color Scheme
" colorscheme jellybeans

" Enable filetype plugins
filetype on
filetype indent on
filetype plugin on
filetype plugin indent on

" Turn backup off
set nobackup
set nowb
set noswapfile

" keep the content on the screen when you exit vim
" set t_ti= t_te=

set foldenable
set foldmethod=indent
set foldlevel=99

" }}}

" MAPPINGS --------{{{
nnoremap <F1> <Esc>
inoremap <F1> <Esc>
vnoremap <F1> <Esc>

nnoremap ; :

" switch # *
nnoremap # *
nnoremap * #

" easy move
nnoremap [w :tabprevious<cr>
nnoremap ]w :tabnext<cr>
nnoremap [W :tabfirst<cr>
nnoremap ]W :tablast<cr>

nnoremap [b :bprevious<cr>
nnoremap ]b :bnext<cr>
nnoremap [B :bfirst<cr>
nnoremap ]B :blast<cr>

nnoremap [l :lprevious<cr>
nnoremap ]l :lnext<cr>
nnoremap [L :lfirst<cr>
nnoremap ]L :llast<cr>

nnoremap [q :cprevious<cr>
nnoremap ]q :cnext<cr>
nnoremap [Q :cfirst<cr>
nnoremap ]Q :clast<cr>

nnoremap [t :tprevious<cr>
nnoremap ]t :tnext<cr>
nnoremap [T :tfirst<cr>
nnoremap ]T :tlast<cr>

" close windows, tabs, quickfix-win, localtion-win
nnoremap <Leader>cw :close<cr>
nnoremap <Leader>ct :tabclose<cr>
nnoremap <Leader>cW :close!<cr>
nnoremap <Leader>cT :tabclose!<cr>
nnoremap <Leader>cq :ccl<cr>
nnoremap <Leader>cl :lcl<cr>

" new a window or tab
" nnoremap <Leader>nw :new<cr>
nnoremap <Leader>nt :tabnew<cr>

"" window
" nnoremap <leader>ws :split<CR>
" nnoremap <leader>wv :vsplit<CR>

" <Leader>[1-9] move to tab [1-9]
for s:i in range(1, 9)
  execute 'nnoremap <Leader>' . s:i . ' ' . s:i . 'gt'
endfor

" repeat in opposite direction
noremap \ ,

" Quit
inoremap <C-q> <esc>:q<cr>
nnoremap <C-q> :q<cr>
vnoremap <C-q> <esc>
nnoremap <Leader>q :q<cr>
nnoremap <Leader>Q :qa!<cr>

" w!! to sudo & write a file
cmap w!! w !sudo tee >/dev/null %

" movement in command-edit mode
cnoremap <C-a> <HOME>
cnoremap <C-h> <left>
cnoremap <C-j> <down>
cnoremap <C-k> <up>
cnoremap <C-l> <right>

" Movement in insert mode
imap <C-e> <END>
imap <C-a> <HOME>
inoremap <C-h> <left>
inoremap <C-l> <right>
inoremap <C-j> <down>
inoremap <C-k> <up>
inoremap <C-^> <C-o><C-^> " edit alternate file

" qq to record, Q to replay
nnoremap Q @q

nnoremap Y y$

" Open new line below and above current line, use `.` repeat.
nnoremap <leader>o o<esc>
nnoremap <leader>O O<esc>

" Save
inoremap <C-s> <C-O>:update<cr>
nnoremap <C-s> :update<cr>

" Disable CTRL-F on tmux
nnoremap <C-f> <nop>
nmap <Leader><C-f> <C-f>

" Tags
" nnoremap <C-]> g<C-]>
" nnoremap g[ :pop<cr>

" Moving lines
" nnoremap <silent> <C-k> :move-2<cr>
" nnoremap <silent> <C-j> :move+<cr>
" nnoremap <silent> <C-h> <<
" nnoremap <silent> <C-l> >>

"use <ctrl>+j/k/h/l to switch the right direction just like you use the j/k/h/l to move the cursor
nmap <C-j> <C-W>j
nmap <C-k> <C-W>k
nmap <C-h> <C-W>h
nmap <C-l> <C-W>l

" Visual linewise up and down by default (and use gj gk to go quicker)
noremap <Up> gk
noremap <Down> gj
noremap j gj
noremap k gk

" Remap H and L (top, bottom of screen to left and right end of line)
nnoremap H ^
nnoremap L $
vnoremap H ^
vnoremap L g_

" Do not show stupid q: window
map q: :q

" Exit on j
imap jj <Esc>
vmap jj <Esc>

" // search the visual block
vnoremap // y/<c-r>"<cr>

" flod code: <leader>zz
let s:FoldAll = 0
fun! ToggleAllFold()
    if s:FoldAll == 0
        exe "normal! zM"
        let s:FoldAll = 1
    else
        exe "normal! zR"
        let s:FoldAll = 0
    endif
endfun
noremap <leader>zz :call ToggleAllFold()<cr>

" set relativenumber
" map <silent><F2> :set relativenumber!<CR>

function! HideNumber()
  if(&relativenumber == &number)
    set relativenumber! number!
  elseif(&number)
    set number!
  else
    set relativenumber!
  endif
  set number?
endfun
nnoremap <F2> :call HideNumber()<CR>

" Toggle highlight
noremap <silent><leader>/ :set nohls!<CR>
" }}}

" AUTO CMD --------{{{
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
    " edit vimrc
    nnoremap <leader>ev :vsplit $MYVIMRC<cr>
    nnoremap <leader>sv :source $MYVIMRC<cr>
augroup END

augroup filetype_tmux_conf
    autocmd!
    autocmd FileType tmux setlocal foldmethod=markers
augroup END

" augroup json_lang
"     autocmd!
"     autocmd BufNewFile,BufRead *.html setlocal nowrap
"     autocmd FileType json nmap <leader> =  :%!jq .<CR>
"     autocmd FileType json vmap <leader> =  :%!jq .<CR>
"     autocmd FileType json set sw=2 ts=2
" augroup END

augroup vagrant
  autocmd!
  autocmd BufRead,BufNewFile Vagrantfile set filetype=ruby
augroup END


function! s:helptab()
  if &buftype == 'help' 
    wincmd T
    nnoremap <buffer> q :q<cr>
  endif
endfunction
augroup vimrc
    autocmd!
    autocmd BufEnter *.txt call s:helptab()

    autocmd vimenter * ++nested colorscheme gruvbox

    autocmd InsertEnter * :set norelativenumber number
    autocmd InsertLeave * :set relativenumber

    autocmd VimResized * wincmd =

    if has("autocmd")
        " Highlight TODO, FIXME, NOTE, etc.
        if v:version > 701
            autocmd Syntax * call matchadd('Todo',  '\W\zs\(TODO\|FIXME\|CHANGED\|DONE\|XXX\|BUG\|HACK\)')
            autocmd Syntax * call matchadd('Debug', '\W\zs\(NOTE\|INFO\|IDEA\|NOTICE\)')
        endif
    endif

    " autocmd BufReadPost quickfix,location nnoremap <buffer> v <C-w><Enter><C-w>L
    " autocmd BufReadPost quickfix,location nnoremap <buffer> s <C-w><Enter><C-w>K
augroup END

" function! AutoSetFileHead()
"     if &filetype == 'sh'
"         call setline(1, "\#!/bin/bash")
"     endif

"     normal G
"     normal o
"     normal o
" endfun
" autocmd BufNewFile *.sh exec ":call AutoSetFileHead()"

" }}}

" ABBR --------{{{
iabbrev thsi this
iabbrev cosnt const

function! SetupCommandAbbrs(from, to)
  exec 'cnoreabbrev <expr> '.a:from
        \ .' ((getcmdtype() ==# ":" && getcmdline() ==# "'.a:from.'")'
        \ .'? ("'.a:to.'") : ("'.a:from.'"))'
endfunction

" coc-nvim
call SetupCommandAbbrs('CL', 'CocList')
call SetupCommandAbbrs('CC', 'CocConfig')
" call SetupCommandAbbrs('S', 'CocSearch')
" call SetupCommandAbbrs('CR', 'CocRestart')

" vim-plug
call SetupCommandAbbrs('PU', 'PlugUpdate')
call SetupCommandAbbrs('PC', 'PlugClean')

" vim-choosewin
" call SetupCommandAbbrs('CW', 'ChooseWin')

" call SetupCommandAbbrs('MP', 'MarkdownPreview')
" }}}