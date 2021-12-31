require("trouble").setup({
  icons = false,
  fold_open = "-", -- icon used for open folds
  fold_closed = "+", -- icon used for closed folds
  indent_lines = false, -- add an indent guide below the fold icons
  mode = "lsp_document_diagnostics",
  signs = {
    -- icons / text used for a diagnostic
    error = "error",
    warning = "warn",
    hint = "hint",
    information = "info",
  },
  use_lsp_diagnostic_signs = true, -- enabling this will use the signs defined in your lsp client
})

local opts = {
  silent = true,
  noremap = true,
}
vim.api.nvim_set_keymap("n", "<leader>tt", "<cmd>TroubleToggle<cr>", opts)
vim.api.nvim_set_keymap(
  "n",
  "<leader>tw",
  "<cmd>Trouble lsp_workspace_diagnostics<cr>",
  opts
)
vim.api.nvim_set_keymap(
  "n",
  "<leader>tb",
  "<cmd>Trouble lsp_document_diagnostics<cr>",
  opts
)
