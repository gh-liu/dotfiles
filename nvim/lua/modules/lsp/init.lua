local status_ok, lspconf = pcall(require, "lspconfig")
if not status_ok then
  return
end

-- vim.lsp.set_log_level("debug")

local load_lsp_conf = function(conf)
  return require("modules.lsp." .. conf)
end

load_lsp_conf("diagnostic").setup()
load_lsp_conf("handlers").setup()

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local servers = {
  bashls = true,
  vimls = true,
  gopls = true,
  sumneko_lua = true,
  jsonls = true,
  yamlls = true,
  rust_analyzer = true,
  tsserver = true,
  dockerls = true,
  dotls = true,
  clangd = true,
  zls = true,
}

local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok, _ = pcall(require, "cmp_nvim_lsp")
if ok then
  capabilities = require("cmp_nvim_lsp").update_capabilities(capabilities)
else
  capabilities.textDocument.completion.completionItem.snippetSupport = true
  capabilities.textDocument.completion.completionItem.preselectSupport = true
  capabilities.textDocument.completion.completionItem.insertReplaceSupport =
    true
  capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
  capabilities.textDocument.completion.completionItem.deprecatedSupport = true
  capabilities.textDocument.completion.completionItem.commitCharactersSupport =
    true
  capabilities.textDocument.completion.completionItem.tagSupport = {
    valueSet = { 1 },
  }
  capabilities.textDocument.completion.completionItem.resolveSupport = {
    properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
    },
  }
end

local on_attach = function(client, bufnr)
  local function buf_set_option(...)
    vim.api.nvim_buf_set_option(bufnr, ...)
  end

  -- Enable completion triggered by <c-x><c-o>
  buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

  -- Mappings.
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  -- hover
  gh.map("n", "K", vim.lsp.buf.hover)
  gh.map("n", "<c-k>", vim.lsp.buf.signature_help)
  -- rename
  gh.map("n", "<leader>rn", vim.lsp.buf.rename)
  -- diagnostic
  gh.map("n", "[d", vim.diagnostic.goto_prev)
  gh.map("n", "]d", vim.diagnostic.goto_next)
  gh.map("n", "<leader>dd", vim.diagnostic.open_float)
  -- something else
  gh.map("n", "<leader>F", vim.lsp.buf.formatting)

  load_lsp_conf("code_lens").on_attach(client, bufnr)
  load_lsp_conf("diagnostic").on_attach(client, bufnr)
  load_lsp_conf("formatting").on_attach(client, bufnr)
  load_lsp_conf("highlight").on_attach(client, bufnr)
  load_lsp_conf("plugins").on_attach(client, bufnr)
end

local on_init = function(client)
  client.config.flags = client.config.flags or {}
  client.config.flags.allow_incremental_sync = true
end

for server, use in pairs(servers) do
  if not use then
    return
  end

  local exist, config = pcall(require, "modules.lsp.server." .. server)
  if not exist then
    config = {}
  end

  config = vim.tbl_deep_extend("force", {
    on_init = on_init,
    on_attach = on_attach,
    capabilities = capabilities,
    flags = {
      debounce_text_changes = nil,
    },
  }, config)

  -- print(vim.inspect(config))
  lspconf[server].setup(config)
end

-- suppress irrelevant messages
local notify = vim.notify
vim.notify = function(msg, ...)
  if msg:match("%[lspconfig%]") then
    return
  end

  if msg:match("warning: multiple different client offset_encodings") then
    return
  end

  notify(msg, ...)
end
