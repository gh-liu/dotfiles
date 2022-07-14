local M = {}

M.setup = function()
  vim.diagnostic.config({
    severity_sort = true,
    virtual_text = { spacing = 4, prefix = "●" },
    update_in_insert = true,
  })

  -- ○ ●
  local lsp_signs = require("core.config").lsp_icons
  local signs = {
    Error = lsp_signs.Error,
    Warn = lsp_signs.Warn,
    Hint = lsp_signs.Hint,
    Info = lsp_signs.Info,
  }

  for type, icon in pairs(signs) do
    local hl = "DiagnosticSign" .. type
    vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
  end
end
return M
