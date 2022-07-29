local M = {}

M.on_attach = function(client, bufnr)
  -- lsp_menu
  local lsp_menu_exist, lsp_menu = pcall(require, "lsp_menu")
  if lsp_menu_exist then
    lsp_menu.on_attach(client, bufnr)
    vim.keymap.set(
      "n",
      "<leader>ca",
      require("lsp_menu").codeaction.run,
      { buffer = bufnr }
    )
    vim.keymap.set(
      "n",
      "<leader>cl",
      require("lsp_menu").codelens.run,
      { buffer = bufnr }
    )
  end

  -- navic
  local navic_exist, navic = pcall(require, "nvim-navic")
  if navic_exist then
    navic.attach(client, bufnr)
  end

  local inlay_hints_exist, inlay_hints = pcall(require, "inlay-hints")
  if inlay_hints_exist then
    inlay_hints.on_attach(client, bufnr)
  end
end

return M
