local create_autocmd = as.create_autocmd

create_autocmd("BufWinEnter", { command = [[checktime]] })
create_autocmd("BufReadPost", { command = [[normal! g`"]] })

create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 120 })
  end,
})

create_autocmd("BufEnter", {
  pattern = "*.txt",
  callback = function()
    if vim.bo.buftype == "help" then
      vim.api.nvim_command([[wincmd T]])
    end
  end,
})

function OrgImports(wait_ms)
  local params = vim.lsp.util.make_range_params(0)
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

create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
    OrgImports(1000)
  end,
})
