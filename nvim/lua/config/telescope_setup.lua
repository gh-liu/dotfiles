local map = require('utils').map

local silent = {
    silent = true
}

-- File Pickers
map('n', '<c-p>', [[<cmd>Telescope find_files<cr>]], silent)
map('i', '<c-p>', [[<cmd>Telescope find_files<cr>]], silent)
map('n', '<leader>fw', [[<cmd>Telescope grep_string<cr>]], silent)
map('n', '<leader>ff', [[<cmd>Telescope live_grep<cr>]], silent)
map('n', '<leader>fb', [[<cmd>Telescope file_browser<cr>]], silent)

-- map('n', '<leader>fr', [[<cmd>Telescope frecency<cr>]], silent)

-- Vim Pickers
-- map('n', '<leader>b', [[<cmd>Telescope buffers<cr>]], silent)
map('i', '<c-b>', [[<cmd>Telescope buffers<cr>]], silent)
map('n', '<c-b>', [[<cmd>Telescope buffers<cr>]], silent)

map('n', '<leader>fh', [[<cmd>Telescope help_tags<cr>]], silent)
map('n', '<leader>fm', [[<cmd>Telescope marks<cr>]], silent)

-- Git Pickers
map('n', '<c-g>', [[<cmd>Telescope git_files<cr>]], silent)
map('i', '<c-g>', [[<cmd>Telescope git_files<cr>]], silent)

-- Neovim LSP Pickers
-- map('n', '<leader>r', [[<cmd>Telescope lsp_references<cr>]], silent)
-- map('n', '<leader>i', [[<cmd>Telescope lsp_implementations<cr>]], silent)
map('n', '<leader>a', [[<cmd>Telescope lsp_code_actions<cr>]], silent)
map('n', '<leader>dw', [[<cmd>Telescope diagnostics<cr>]], silent)
map('n', '<leader>db', [[<cmd>Telescope diagnostics bufnr=0<cr>]], silent)

map('n', '<c-d>', [[<cmd>Telescope lsp_definitions<cr>]], silent)
map('n', 'gd', [[<cmd>Telescope lsp_definitions<cr>]], silent)
map('n', 'gD', [[<cmd>Telescope lsp_type_definitions<cr>]], silent)

map('n', 'gr', [[<cmd>Telescope lsp_references<cr>]], silent)
map('n', 'gi', [[<cmd>Telescope lsp_implementations<cr>]], silent)

map('n', '<leader>g0', [[<cmd>Telescope lsp_document_symbols<cr>]], silent)
map('n', '<leader>gW', [[<cmd>Telescope lsp_dynamic_workspace_symbols<cr>]], silent)

-- Treesitter Picker
-- map('n', '<leader>d', [[<cmd>Telescope treesitter<cr>]], silent)

-- Extension Pickers
-- map('n', '<c-e>', [[<cmd>Telescope frecency<cr>]], silent)
