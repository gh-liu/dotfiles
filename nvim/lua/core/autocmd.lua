local au = as.au

local cmd = vim.api.nvim_command

au.BufWinEnter = { "*", [[checktime]] }
au.BufReadPost = { "*", [[normal! g`"]] }

au.TextYankPost = function()
  vim.highlight.on_yank({ higroup = "IncSearch", timeout = 120 })
end

au.BufEnter = {
  "*.txt",
  function()
    if vim.bo.buftype == "help" then
      cmd([[wincmd T]])
    end
  end,
}

function OrgImports(wait_ms)
  local params = vim.lsp.util.make_range_params()
  params.context = { only = { "source.organizeImports" } }
  local result = vim.lsp.buf_request_sync(
    0,
    "textDocument/codeAction",
    params,
    wait_ms
  )
  for _, res in pairs(result or {}) do
    for _, r in pairs(res.result or {}) do
      if r.edit then
        vim.lsp.util.apply_workspace_edit(r.edit)
      else
        vim.lsp.buf.execute_command(r.command)
      end
    end
  end
end

au.BufWritePre = { "*.go", OrgImports, { 1000 } }
