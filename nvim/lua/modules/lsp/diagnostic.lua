vim.diagnostic.config({
  severity_sort = true,
  virtual_text = false,
  update_in_insert = true,
})

local function set_lsp_sign(name, text)
  vim.fn.sign_define(name, { text = text, texthl = name })
end

set_lsp_sign("DiagnosticSignError", "●")
set_lsp_sign("DiagnosticSignWarn", "●")
set_lsp_sign("DiagnosticSignInfo", "●")
set_lsp_sign("DiagnosticSignHint", "○")
