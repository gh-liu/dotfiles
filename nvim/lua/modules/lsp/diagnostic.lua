local create_autocmd = vim.api.nvim_create_autocmd

local config = gh.lazy_require("core.config")

local M = {}

M.setup = function()
  vim.diagnostic.config({
    severity_sort = true,
    -- virtual_text = false,
    virtual_text = {
      spacing = 4,
      -- prefix = "x",
      -- source = "always",
    },
    update_in_insert = false,
  })

  -- signs
  local lsp_signs = require("core.config").icons.lsp
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

M.on_attach = function(client, bufnr)
  -- Show diagnostic popup on cursor hover
  create_autocmd("CursorHold", {
    buffer = bufnr,
    callback = function()
      local opts = {
        focusable = false,
        close_events = {
          "BufLeave",
          "CursorMoved",
          "InsertEnter",
          "FocusLost",
        },
        border = config.border.rounded,
        source = "always",
        prefix = " ",
        scope = "cursor",
      }
      vim.diagnostic.open_float(nil, opts)
    end,
  })
end
return M
