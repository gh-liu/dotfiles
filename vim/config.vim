" With a map leader it's possible to do extra key combinations
let mapleader=','
" Set utf8 as standard encoding and en_US as the standard language
set encoding=utf8
" Set to auto read when a file is changed from the outside
set autoread
" be iMproved
set nocompatible 
" For regular expressions turn magic on
set magic
" Sets how many lines of history VIM has to remember{{{}}}
set history=5000

" => VIM user interface
" Enable the use of the mouse
set mouse=a
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
" // search the visual block
" vnoremap // y/<c-r>"<cr>
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
" Set 7 lines under the cursor - when moving vertically using j/k
set so=10
" show the cursor position all the time
set ruler
" Turn on the wild menu, complete the command
set wildmenu
" Height of the command bar
set cmdheight=2
" Automatically save before :next, :make etc.
set autowrite 

set complete-=i

" Don't pass messages to |ins-completion-menu|.
set shortmess+=c

" => Colors and Fonts
" Enable syntax highlighting
syntax enable 
" Enable 256 colors palette in Gnome Terminal
if $COLORTERM == 'gnome-terminal'
    set t_Co=256
endif
set background=dark
" Color Scheme
" colorscheme jellybeans

" => Files, backups
" Enable filetype plugins
filetype on
filetype plugin on
filetype indent on
" Turn backup off
set nobackup
set nowb
set noswapfile

set pumheight=10             " Completion window max size
" Automatically resize screens to be equally the same
autocmd VimResized * wincmd =

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