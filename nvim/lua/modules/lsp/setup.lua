local M = {}

M.capabilities = vim.lsp.protocol.make_client_capabilities()
M.capabilities.textDocument.completion.completionItem.snippetSupport = true
M.capabilities.textDocument.completion.completionItem.preselectSupport = true
M.capabilities.textDocument.completion.completionItem.insertReplaceSupport =
  true
M.capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
M.capabilities.textDocument.completion.completionItem.deprecatedSupport = true
M.capabilities.textDocument.completion.completionItem.commitCharactersSupport =
  true
M.capabilities.textDocument.completion.completionItem.tagSupport = {
  valueSet = { 1 },
}
M.capabilities.textDocument.completion.completionItem.resolveSupport = {
  properties = {
    "documentation",
    "detail",
    "additionalTextEdits",
  },
}

M.on_attach = function(client, bufnr)
  local filetype = vim.api.nvim_buf_get_option(0, "filetype")

  local function buf_set_option(...)
    vim.api.nvim_buf_set_option(bufnr, ...)
  end

  -- Enable completion triggered by <c-x><c-o>
  buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  -- go-to-definition
  -- as.map('n','<c-]>','<cmd>lua vim.lsp.buf.definition()<cr>')
  -- as.map('n', '<c-d>', '<cmd>lua vim.lsp.buf.definition()<cr>')
  -- as.map('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>')
  -- as.map('n', 'gd', '<cmd>lua vim.lsp.buf.declaration()<cr>')
  -- as.map('n', 'gD', '<cmd>lua vim.lsp.buf.type_definition()<cr>')
  -- find-references
  -- as.map('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>')
  -- hover
  as.map("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>")
  as.map("n", "<c-k>", "<cmd>lua vim.lsp.buf.signature_help()<cr>")
  -- completion
  -- rename
  as.map("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>")
  -- format
  -- as.map('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>')
  -- refactor
  -- as.map('n', '<leader>a', '<cmd>lua vim.lsp.buf.code_action()<cr>')
  -- diagnostic
  as.map("n", "<leader>dd", "<cmd>lua vim.diagnostic.open_float()<CR>")
  -- as.map('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>')
  as.map("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
  as.map("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>")
  -- something else
  -- as.map('n', 'g0', '<cmd>lua vim.lsp.buf.document_symbol()<cr>')
  -- as.map('n', 'gW', '<cmd>lua vim.lsp.buf.workspace_symbol()<cr>')
  -- as.map('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>')
  -- as.map('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>')
  -- as.map('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>')
  as.map("n", "<leader>F", "<cmd>lua vim.lsp.buf.formatting()<CR>")
  as.map("n", "<leader>L", "<cmd>lua vim.lsp.codelens.run()<CR>")

  -- print(vim.inspect(client.resolved_capabilities))

  if client.resolved_capabilities.document_highlight then
    vim.cmd([[
      augroup lsp_highlight
        autocmd! * <buffer>
        autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
        autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
      augroup END
    ]])
  end

  if client.resolved_capabilities.code_lens then
    vim.cmd("highlight default link LspCodeLens WarningMsg")
    vim.cmd("highlight default link LspCodeLensText WarningMsg")
    vim.cmd("highlight default link LspCodeLensTextSign LspCodeLensText")
    vim.cmd("highlight default link LspCodeLensTextSeparator Boolean")
    -- vim.lsp.codelens.refresh()
    vim.cmd([[
      augroup lsp_codelens
        au! * <buffer>
        autocmd BufEnter ++once         <buffer> lua vim.lsp.codelens.refresh()
        autocmd BufWritePost,CursorHold <buffer> lua vim.lsp.codelens.refresh()
      augroup END
    ]])
  end

  local filetype_attach = require("modules.lsp.filetype_attach")
  filetype_attach[filetype](client)
end

M.on_init = function(client)
  client.config.flags = client.config.flags or {}
  client.config.flags.allow_incremental_sync = true
end

return M
