vim.cmd([[
    autocmd FileType toml setlocal commentstring=#\ %s
    nmap <C-_> gcc
    imap <C-_> <C-O>gcc
    vmap <C-_> gc
]])
