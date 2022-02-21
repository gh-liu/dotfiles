local status_ok, lspconf = pcall(require, "lspconfig")
if not status_ok then
  return
end

local handler = require("modules.lsp.handlers")

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
local servers = {}

servers.bashls = {
  filetypes = { "sh", "zsh" },
}
servers.vimls = {}
-- servers.clojure_lsp = {}
-- servers.rust_analyzer = {}

-- golang
servers.gopls = {
  cmd = { "gopls", "--remote=auto" },
  filetypes = { "go", "gomod", "gotmpl" },
  single_file_support = true,
  settings = {
    -- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
    gopls = {
      -- usePlaceholders = false,
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
  init_options = {
    usePlaceholders = true,
  },
}
handler.setup_auto_format("go")

-- lua
local runtime_path = vim.split(package.path, ";")
table.insert(runtime_path, "lua/?.lua")
table.insert(runtime_path, "lua/?/init.lua")
servers.sumneko_lua = {
  -- The default `cmd` assumes that the `lua-language-server` binary can be found in $PATH
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = "LuaJIT",
        -- Setup your lua path
        path = runtime_path,
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { "vim", "as" },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        library = vim.api.nvim_get_runtime_file("", true),
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}
handler.setup_auto_format("lua", "lua require('stylua-nvim').format_file()")

for server, config in pairs(servers) do
  local default = {
    capabilities = handler.capabilities,
    on_attach = handler.on_attach,
    -- autostart = as.is_lsp_autostart(server),
    flags = {
      -- This will be the default in neovim 0.7+
      debounce_text_changes = 150,
    },
  }

  for k, v in pairs(default) do
    config[k] = v
  end
  -- print(vim.inspect(config))

  lspconf[server].setup(config)
end
