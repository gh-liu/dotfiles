setlocal conceallevel=2
setlocal concealcursor=nv

" setlocal tagfunc=v:lua.require'liu.lsp.helper'.symbol_tagfunc

" lua require('dap.ext.autocompl').attach()

lua vim.keymap.set("n", "<leader>dd", ":%d_<cr>", { buffer = 0, silent = true })
