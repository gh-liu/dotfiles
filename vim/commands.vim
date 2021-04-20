" VimScript file settings ----------------------------------{{{
augroup filetype_vim
    autocmd!
    autocmd FileType vim setlocal foldmethod=marker
    " edit vimrc
    nnoremap <leader>ev :vsplit $MYVIMRC<cr>
    nnoremap <leader>sv :source $MYVIMRC<cr>
    autocmd FileType vim :iabbrev <buffer> --- ----------------------------------{{{
augroup END
" }}} }}}

" .tmux.conf ----------------------------------{{{
augroup filetype_tmux_conf
    autocmd!
    autocmd FileType tmux setlocal foldmethod=marker
    autocmd FileType tmux :iabbrev <buffer> --- ----------------------------------{{{
augroup END
" }}}

" JSON ----------------------------------{{{
augroup json_lang
    autocmd!
    autocmd BufNewFile,BufRead *.html setlocal nowrap
    autocmd FileType json nmap <leader> =  :%!jq .<CR>
    autocmd FileType json vmap <leader> =  :%!jq .<CR>
    autocmd FileType json set sw=2 ts=2
augroup END
" }}}

augroup vagrant
  au!
  au BufRead,BufNewFile Vagrantfile set filetype=ruby
augroup END

" vimrc ----------------------------------{{{
augroup vimrc
    autocmd!
augroup END

function! s:helptab()
  if &buftype == 'help' 
    wincmd T
    nnoremap <buffer> q :q<cr>
  endif
endfunction

autocmd vimrc BufEnter *.txt call s:helptab()

autocmd vimrc vimenter * ++nested colorscheme gruvbox
" }}}