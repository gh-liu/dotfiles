" exit LspInfo window with q"
augroup LspInfo
    au!
    au FileType lspinfo nnoremap <silent> <buffer> q :q<CR>
augroup END

" trim trailing white space
augroup TrimTrailing
    au!
    au BufWritePre * %s/\s\+$//e
    au BufWritePre * %s/\n\+\%$//e
augroup END
