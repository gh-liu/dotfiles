local utils = require('utils')
local opt = utils.opt
local map = utils.map
local autocmd = utils.autocmd

local lsp = require "lspconfig"

-- lsp settings
vim.lsp.set_log_level("debug")

-- lsp keybingdings
local opts = { noremap = true, silent = true }
-- go-to-definition
-- map('n','<c-]>','<cmd>lua vim.lsp.buf.definition()<cr>', opts)
map('n','<c-d>','<cmd>lua vim.lsp.buf.definition()<cr>', opts)
map('n','gd','<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
map('n','gi','<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
map('n','gD','<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
-- find-references
map('n','gr','<cmd>lua vim.lsp.buf.references()<cr>', opts)
-- hover
map('n','K','<cmd>lua vim.lsp.buf.hover()<cr>', opts)
map('n','<c-k>','<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
-- completion
-- rename
map('n','<leader>rn','<cmd>lua vim.lsp.buf.rename()<cr>', opts)
-- format
-- refactor
map('n','<leader>a','<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
-- diagnostic
map('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
map('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
-- something else
map('n','g0','<cmd>lua vim.lsp.buf.document_symbol()<cr>', opts)
map('n','gW','<cmd>lua vim.lsp.buf.workspace_symbol()<cr>', opts)

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

function goimports(timeout_ms)
  local context = { only = { "source.organizeImports" } }
  vim.validate { context = { context, "t", true } }

  local params = vim.lsp.util.make_range_params()
  params.context = context

  -- See the implementation of the textDocument/codeAction callback
  -- (lua/vim/lsp/handler.lua) for how to do this properly.
  local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, timeout_ms)
  if not result or next(result) == nil then return end
  local actions = result[1].result
  if not actions then return end
  local action = actions[1]

  -- textDocument/codeAction can return either Command[] or CodeAction[]. If it
  -- is a CodeAction, it can have either an edit, a command or both. Edits
  -- should be executed first.
  if action.edit or type(action.command) == "table" then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit)
    end
    if type(action.command) == "table" then
      vim.lsp.buf.execute_command(action.command)
    end
  else
    vim.lsp.buf.execute_command(action)
  end
end

autocmd('goimports', {[[BufWritePre *.go lua goimports(1000)]]}, true)

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

