local M = {}

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

  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(
    vim.lsp.handlers.hover,
    { border = "rounded" }
  )
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(
    vim.lsp.handlers.signature_help,
    { border = "rounded" }
  )
end
return M
