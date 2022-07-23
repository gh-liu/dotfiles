local M = {}

local config = gh.lazy_require("core.config")

M.setup = function()
  -- Workaround to handle pyright: Unsupported command or any other commands that are sent
  -- from null-ls to other lsp clients
  -- @see https://github.com/jose-elias-alvarez/null-ls.nvim/issues/197#issuecomment-922792992
  local default_exe_handler = vim.lsp.handlers["workspace/executeCommand"]
  vim.lsp.handlers["workspace/executeCommand"] =
    function(err, result, ctx, config)
      -- supress NULL_LS error msg
      local prefix = "NULL_LS"

      if err and ctx.params.command:sub(1, #prefix) == prefix then
        return
      end

      return default_exe_handler(err, result, ctx, config)
    end

  local float_options = {
    border = config.border.rounded,
    max_width = math.ceil(vim.api.nvim_win_get_width(0) * 0.6),
    max_height = math.ceil(vim.api.nvim_win_get_height(0) * 0.8),
  }

  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
    vim.lsp.handlers.hover,
    float_options
  )
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
    vim.lsp.handlers.signature_help,
    float_options
  )
  vim.lsp.handlers["textDocument/show_line_diagnostics"] = vim.lsp.with(
    vim.lsp.handlers.show_line_diagnostics,
    float_options
  )
end

return M
