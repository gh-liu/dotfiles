local create_autocmd = vim.api.nvim_create_autocmd
local M = {}

M.on_attach = function(client, bufnr)
  -- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#highlight-symbol-under-cursor
  if client.resolved_capabilities.document_highlight then
    vim.api.nvim_create_augroup("lsp_document_highlight", {
      clear = false,
    })
    vim.api.nvim_clear_autocmds({
      buffer = bufnr,
      group = "lsp_document_highlight",
    })
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      group = "lsp_document_highlight",
      buffer = bufnr,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd("CursorMoved", {
      group = "lsp_document_highlight",
      buffer = bufnr,
      callback = vim.lsp.buf.clear_references,
    })
  end
end
return M
