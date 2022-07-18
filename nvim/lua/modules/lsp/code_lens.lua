local create_autocmd = vim.api.nvim_create_autocmd
local M = {}

M.on_attach = function(client, bufnr)
  if client.resolved_capabilities.code_lens then
    vim.cmd("highlight! link LspCodeLens LspDiagnosticsHint")
    vim.cmd("highlight! link LspCodeLensText LspDiagnosticsInformation")
    vim.cmd("highlight! link LspCodeLensTextSign LspDiagnosticsSignInformation")
    vim.cmd("highlight! link LspCodeLensTextSeparator Boolean")

    local lsp_codelens = vim.api.nvim_create_augroup(
      "lsp_codelens",
      { clear = false }
    )

    create_autocmd("BufEnter", {
      buffer = bufnr,
      callback = function()
        vim.lsp.codelens.refresh()
      end,
      group = lsp_codelens,
      once = true,
    })

    create_autocmd({ "BufWritePost", "CursorHold" }, {
      buffer = bufnr,
      callback = function()
        vim.lsp.codelens.refresh()
      end,
      group = lsp_codelens,
    })
  end
end
return M
