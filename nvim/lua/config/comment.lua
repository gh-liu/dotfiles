require('Comment').setup()
-- <C-/> 
local opts = {
    silent = true
}
vim.api.nvim_set_keymap('v', '<C-_>', 'gc', opts)
vim.api.nvim_set_keymap('n', '<C-_>', 'gcc', opts)
vim.api.nvim_set_keymap('i', '<C-_>', '<C-O>gcc', opts)
