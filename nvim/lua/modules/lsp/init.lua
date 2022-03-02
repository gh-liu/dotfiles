local status_ok, lspconf = pcall(require, "lspconfig")
if not status_ok then
  return
end

local handler = require("modules.lsp.handlers")

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local servers = {
  "bashls",
  "vimls",
  "gopls",
  "sumneko_lua",
  "jsonls",
  "yamlls",
  "rust_analyzer",
  "tsserver",
  "dockerls",
}

handler.setup_auto_format("go")
-- handler.setup_auto_format("go", [[lua require('modules.lang.format').format_file("gofumpt","-w")]])
handler.setup_auto_format("lua", "lua require('stylua-nvim').format_file()")
handler.setup_auto_format("json")

for _, server in ipairs(servers) do
  local default = {
    capabilities = handler.capabilities,
    on_attach = handler.on_attach,
    -- autostart = as.is_lsp_autostart(server),
    flags = {
      -- This will be the default in neovim 0.7+
      debounce_text_changes = 150,
    },
  }

  local exist, config = pcall(require, "modules.lsp.server." .. server)
  if exist then
    for k, v in pairs(default) do
      config[k] = v
    end
  else
    config = {}
  end
  -- print(vim.inspect(config))
  lspconf[server].setup(config)
end
