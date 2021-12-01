local map = require('utils').map

local silent = {
    silent = true
}

-- File Pickers
map('n', '<c-p>', [[<cmd>Telescope find_files<cr>]], silent)
map('i', '<c-p>', [[<cmd>Telescope find_files<cr>]], silent)
map('n', '<leader>w', [[<cmd>Telescope grep_string<cr>]], silent)
map('n', '<leader>f', [[<cmd>Telescope live_grep<cr>]], silent)

-- Vim Pickers
-- map('n', '<leader>b', [[<cmd>Telescope buffers<cr>]], silent)
map('i', '<c-b>', [[<cmd>Telescope buffers<cr>]], silent)
map('n', '<c-b>', [[<cmd>Telescope buffers<cr>]], silent)

-- Git Pickers
map('n', '<c-g>', [[<cmd>Telescope git_files<cr>]], silent)
map('i', '<c-g>', [[<cmd>Telescope git_files<cr>]], silent)

-- Neovim LSP Pickers
map('n', '<leader>r', [[<cmd>Telescope lsp_references<cr>]], silent)
map('n', '<leader>i', [[<cmd>Telescope lsp_implementations<cr>]], silent)

-- Treesitter Picker
-- map('n', '<leader>d', [[<cmd>Telescope treesitter<cr>]], silent)

-- Extension Pickers
-- map('n', '<c-e>', [[<cmd>Telescope frecency<cr>]], silent)
