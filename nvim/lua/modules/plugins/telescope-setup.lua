local map = as.map

-- File Pickers
map("n", "<c-p>", [[<cmd>Telescope find_files<cr>]])
map("i", "<c-p>", [[<cmd>Telescope find_files<cr>]])
map("n", "<leader>fw", [[<cmd>Telescope grep_string<cr>]])
map("n", "<leader>ff", [[<cmd>Telescope live_grep<cr>]])

-- map('n', '<leader>fr', [[<cmd>Telescope frecency<cr>]])

-- Vim Pickers
-- map('n', '<leader>b', [[<cmd>Telescope buffers<cr>]])
map("i", "<c-b>", [[<cmd>Telescope buffers<cr>]])
map("n", "<c-b>", [[<cmd>Telescope buffers<cr>]])

map("n", "<leader>fh", [[<cmd>Telescope help_tags<cr>]])
map("n", "<leader>fm", [[<cmd>Telescope marks<cr>]])

-- Git Pickers
map("n", "<c-g>", [[<cmd>Telescope git_status<cr>]])
map("i", "<c-g>", [[<cmd>Telescope git_status<cr>]])

-- Neovim LSP Pickers
-- map('n', '<leader>r', [[<cmd>Telescope lsp_references<cr>]])
-- map('n', '<leader>i', [[<cmd>Telescope lsp_implementations<cr>]])
map("n", "<leader>dw", [[<cmd>Telescope diagnostics<cr>]])
map("n", "<leader>db", [[<cmd>Telescope diagnostics bufnr=0<cr>]])

map("n", "<c-d>", [[<cmd>Telescope lsp_definitions<cr>]])
map("n", "gd", [[<cmd>Telescope lsp_definitions<cr>]])
map("n", "gD", [[<cmd>Telescope lsp_type_definitions<cr>]])

map("n", "gr", [[<cmd>Telescope lsp_references<cr>]])
map("n", "gi", [[<cmd>Telescope lsp_implementations<cr>]])

map("n", "<leader>g0", [[<cmd>Telescope lsp_document_symbols<cr>]])
map("n", "<leader>gW", [[<cmd>Telescope lsp_dynamic_workspace_symbols<cr>]])

-- Treesitter Picker
-- map('n', '<leader>d', [[<cmd>Telescope treesitter<cr>]])

-- Extension Pickers
-- map('n', '<c-e>', [[<cmd>Telescope frecency<cr>]])

map("n", ";", "<cmd>Telescope commands<cr>")

vim.cmd(
  [[command! Dotfiles silent lua require('telescope.builtin').git_files({cwd= vim.env.HOME .. "/.config/nvim" })]]
)
