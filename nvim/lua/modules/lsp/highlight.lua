local create_autocmd = vim.api.nvim_create_autocmd
local M = {}

M.on_attach = function(client, bufnr)
  if client.resolved_capabilities.document_highlight then
    local lsp_highlight = vim.api.nvim_create_augroup(
      "lsp_highlight",
      { clear = false }
    )

    create_autocmd("CursorHold", {
      buffer = bufnr,
      callback = function()
        vim.lsp.buf.document_highlight()
      end,
      group = lsp_highlight,
    })

    create_autocmd("CursorMoved", {
      buffer = bufnr,
      callback = function()
        vim.lsp.util.buf_clear_references(0)
      end,
      group = lsp_highlight,
    })
  end
end
return M
