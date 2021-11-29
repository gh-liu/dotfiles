-- <C-/> 
vim.api.nvim_set_keymap('v', '<C-_>', 'gc', {})
vim.api.nvim_set_keymap('n', '<C-_>', 'gcc', {})
vim.api.nvim_set_keymap('i', '<C-_>', '<C-o>gcc', {})
