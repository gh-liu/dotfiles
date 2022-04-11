local create_autocmd = vim.api.nvim_create_autocmd

create_autocmd("BufEnter", {
  pattern = { "*.beancount", "*.bean" },
  command = [[set filetype=beancount]],
})

create_autocmd("FileType", {
  pattern = "beancount",
  callback = function()
    vim.api.nvim_buf_set_var(0, "beancount_root", os.getenv("BEANCOUNT_ROOT"))
    vim.cmd([[
      set nofoldenable
      inoremap . .<C-\><C-O>:AlignCommodity<CR>
      inoremap > <C-R>=strftime('%Y-%m-%d')<CR> * 
      vnoremap L :!bean-format /dev/stdin<CR>
      nnoremap <C-d> :execute ":!bean-doctor context % " . line('.')<CR>
    ]])
  end,
})
