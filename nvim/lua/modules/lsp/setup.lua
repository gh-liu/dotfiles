local create_autocmd = vim.api.nvim_create_autocmd

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
  -- hover
  as.map("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>")
  as.map("n", "<c-k>", "<cmd>lua vim.lsp.buf.signature_help()<cr>")
  -- rename
  as.map("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>")
  -- diagnostic
  as.map("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>")
  as.map("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>")
  as.map("n", "<leader>dd", "<cmd>lua vim.diagnostic.open_float()<CR>")
  -- something else
  as.map("n", "<leader>F", "<cmd>lua vim.lsp.buf.formatting()<CR>")

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

  if client.resolved_capabilities.code_lens then
    vim.cmd("highlight default link LspCodeLens WarningMsg")
    vim.cmd("highlight default link LspCodeLensText WarningMsg")
    vim.cmd("highlight default link LspCodeLensTextSign LspCodeLensText")
    vim.cmd("highlight default link LspCodeLensTextSeparator Boolean")

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

  -- Show diagnostic popup on cursor hover
  create_autocmd("CursorHold", {
    buffer = bufnr,
    callback = function()
      vim.diagnostic.open_float(nil, { focusable = false, scope = "cursor" })
    end,
  })

  require("modules.lsp.extensions").lightbulb(client, bufnr)

  local filetype_attach = require("modules.lsp.filetype_attach")
  filetype_attach[filetype](client)

  require("lsp_menu").on_attach(client, bufnr)
  vim.keymap.set(
    "n",
    "<leader>ca",
    require("lsp_menu").codeaction.run,
    { buffer = bufnr }
  )
  vim.keymap.set(
    "n",
    "<leader>cl",
    require("lsp_menu").codelens.run,
    { buffer = bufnr }
  )
end

M.on_init = function(client)
  client.config.flags = client.config.flags or {}
  client.config.flags.allow_incremental_sync = true
end

return M
