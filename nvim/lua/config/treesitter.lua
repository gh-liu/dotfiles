local tsconf = require('nvim-treesitter.configs')

vim.api.nvim_command('set foldmethod=expr')
vim.api.nvim_command('set foldexpr=nvim_treesitter#foldexpr()')

tsconf.setup {
    ensure_installed = {"go", "gomod", "vim", "bash", "lua", "json", "json5", "yaml", "dockerfile", "toml", "query"},
    sync_install = false, -- install languages synchronously (only applied to `ensure_installed`)
    ignore_install = {}, -- List of parsers to ignore installing
    highlight = {
        enable = true,
        disable = {},
        additional_vim_regex_highlighting = false
    },
    textobjects = {
        select = {
            enable = true,
            -- Automatically jump forward to textobj, similar to targets.vim 
            lookahead = true,
            keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = "@function.outer",
                ["if"] = "@function.inner"
            }
        },
        swap = {
            enable = true,
            swap_next = {
                ["<leader><leader>a"] = "@parameter.inner"
            },
            swap_previous = {
                ["<leader><leader>A"] = "@parameter.inner"
            }
        },
        move = {
            enable = true,
            set_jumps = true, -- whether to set jumps in the jumplist
            goto_next_start = {
                ["]]"] = "@function.outer"
            },
            goto_previous_start = {
                ["[["] = "@function.outer"
            }
        }
    }
}
