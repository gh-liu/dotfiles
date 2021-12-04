local tsconf = require('nvim-treesitter.configs')

tsconf.setup {
    ensure_installed = {"go", "gomod", "vim", "bash", "lua", "json", "json5", "yaml", "dockerfile"},
    sync_install = false, -- install languages synchronously (only applied to `ensure_installed`)
    ignore_install = {}, -- List of parsers to ignore installing
    highlight = {
        enable = true,
        disable = {},
        additional_vim_regex_highlighting = false
    }
}

-- vim.cmd [[
--     set foldmethod=expr
--     set foldexpr=nvim_treesitter#foldexpr()
-- ]]
