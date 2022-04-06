local create_autocmd = as.create_autocmd

vim.b.beancount_root = os.getenv("BEANCOUNT_ROOT")

create_autocmd("BufEnter", {
  pattern = { "*.beancount", "*.bean" },
  command = [[set filetype=beancount]],
})

create_autocmd("FileType", {
  pattern = "beancount",
  command = [[
    set nofoldenable
    inoremap . .<C-\><C-O>:AlignCommodity<CR>
    inoremap > <C-R>=strftime('%Y-%m-%d')<CR> * 
    nnoremap <C-p> :execute ":!bean-doctor context % " . line('.')<CR>
    vnoremap L :!bean-format /dev/stdin<CR>
  ]],
})
