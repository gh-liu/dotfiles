local utils = require('utils')
local opt = utils.opt
local map = utils.map
local autocmd = utils.autocmd

local lsp = require "lspconfig"

-- lsp settings
vim.lsp.set_log_level("debug")

local on_attach = function(client, bufnr)
    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end
    local function buf_set_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
    end

    -- Enable completion triggered by <c-x><c-o>
    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    local opts = {
        noremap = true,
        silent = true
    }

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    -- go-to-definition
    -- buf_set_keymap('n','<c-]>','<cmd>lua vim.lsp.buf.definition()<cr>', opts)
    buf_set_keymap('n', '<c-d>', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
    buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
    buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
    buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
    -- find-references
    buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
    -- hover
    buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>', opts)
    buf_set_keymap('n', '<c-k>', '<cmd>lua vim.lsp.buf.signature_help()<cr>', opts)
    -- completion
    -- rename
    buf_set_keymap('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<cr>', opts)
    -- format
    -- buf_set_keymap('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
    -- refactor
    buf_set_keymap('n', '<leader>a', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
    -- diagnostic
    -- buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
    -- buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
    buf_set_keymap('n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
    buf_set_keymap('n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
    -- something else
    buf_set_keymap('n', 'g0', '<cmd>lua vim.lsp.buf.document_symbol()<cr>', opts)
    buf_set_keymap('n', 'gW', '<cmd>lua vim.lsp.buf.workspace_symbol()<cr>', opts)
    -- buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
    -- buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
    -- buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)

end

local capabilities = require('cmp_nvim_lsp').update_capabilities(vim.lsp.protocol.make_client_capabilities())

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
-- Go
lsp.gopls.setup {
    cmd = {'gopls', '--remote=auto'},
    settings = {
        gopls = {
            -- usePlaceholders = true,
            analyses = {
                unusedparams = true
            },
            staticcheck = true
        }
    },
    init_options = {
        usePlaceholders = true
    },
    capabilities = capabilities,
    on_attach = on_attach
}

function goimports(timeout_ms)
    local context = {
        only = {"source.organizeImports"}
    }
    vim.validate {
        context = {context, "t", true}
    }

    local params = vim.lsp.util.make_range_params()
    params.context = context

    -- See the implementation of the textDocument/codeAction callback
    -- (lua/vim/lsp/handler.lua) for how to do this properly.
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, timeout_ms)
    if not result or next(result) == nil then
        return
    end
    local actions = result[1].result
    if not actions then
        return
    end
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

lsp.golangci_lint_ls.setup {}

-- Bash
lsp.bashls.setup {
    capabilities = capabilities,
    on_attach = on_attach
}

-- Lua
local sumneko_root_path = vim.fn.expand('~') .. [[/env/lsp/lua-language-server]]
local sumneko_binary = sumneko_root_path .. "/bin/Linux/lua-language-server"

local runtime_path = vim.split(package.path, ';')
table.insert(runtime_path, "lua/?.lua")
table.insert(runtime_path, "lua/?/init.lua")

lsp.sumneko_lua.setup {
    cmd = {sumneko_binary, "-E", sumneko_root_path .. "/main.lua"},
    settings = {
        Lua = {
            runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
                -- Setup your lua path
                path = runtime_path
            },
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = {'vim'}
            },
            workspace = {
                -- Make the server aware of Neovim runtime files
                library = vim.api.nvim_get_runtime_file("", true)
            },
            -- Do not send telemetry data containing a randomized but unique identifier
            telemetry = {
                enable = false
            }
        }
    },
    capabilities = capabilities,
    on_attach = on_attach
}

-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
-- for _, lsp_name in ipairs(servers) do
--     lsp[lsp_name].setup {
--         on_attach = on_attach,
--         capabilities = capabilities,
--         flags = {
--             debounce_text_changes = 150
--         }
--     }
-- end
