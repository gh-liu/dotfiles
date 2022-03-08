local status_ok, lspconf = pcall(require, "lspconfig")
if not status_ok then
  return
end

vim.lsp.set_log_level("debug")

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
}

local setup = require("modules.lsp.setup")

for server, use in pairs(servers) do
  if not use then
    return
  end

  local exist, config = pcall(require, "modules.lsp.server." .. server)
  if not exist then
    config = {}
  end

  config = vim.tbl_deep_extend("force", {
    on_init = setup.on_init,
    on_attach = setup.on_attach,
    capabilities = setup.capabilities,
    flags = {
      debounce_text_changes = nil,
    },
  }, config)

  -- print(vim.inspect(config))
  lspconf[server].setup(config)
end
