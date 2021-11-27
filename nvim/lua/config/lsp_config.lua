local utils = require('utils')
local opt = utils.opt
local map = utils.map
local autocmd = utils.autocmd

local lsp = require "lspconfig"

-- lsp settings
vim.lsp.set_log_level("debug")

-- lsp keybingdings
-- go-to-definition
-- find-references
-- hover
-- completion
-- rename
-- format
-- refactor
local opts = { noremap = true, silent = true }
map('n','<c-]>','<cmd>lua vim.lsp.buf.definition()<cr>', opts)
map('n','<c-d>','<cmd>lua vim.lsp.buf.definition()<cr>', opts)
map('n','K','<cmd>lua vim.lsp.buf.hover()<cr>', opts)
map('n','gi','<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
map('n','<c-k>','<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
map('n','gD','<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
map('n','gr','<cmd>lua vim.lsp.buf.references()<cr>', opts)
map('n','g0','<cmd>lua vim.lsp.buf.document_symbol()<cr>', opts)
map('n','gW','<cmd>lua vim.lsp.buf.workspace_symbol()<cr>', opts)
map('n','gd','<cmd>lua vim.lsp.buf.declaration()<cr>', opts)

local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
-- Go
lsp.gopls.setup{
	cmd = {'gopls', '--remote=auto'},
  settings = {
    gopls = {
      -- usePlaceholders = true,
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
  init_options = {
    usePlaceholders = true,
  },
  capabilities = capabilities,
}

-- Bash
lsp.bashls.setup{capabilities = capabilities,}

-- Lua
local sumneko_root_path = vim.fn.expand('~') .. [[/env/lsp/lua-language-server]]
local sumneko_binary = sumneko_root_path .. "/bin/Linux/lua-language-server"

local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, "lua/?.lua")
table.insert(runtime_path, "lua/?/init.lua")

lsp.sumneko_lua.setup {
  cmd = {sumneko_binary, "-E", sumneko_root_path .. "/main.lua"};
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
        -- Setup your lua path
        path = runtime_path,
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = {'vim'},
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
  capabilities = capabilities,
}

