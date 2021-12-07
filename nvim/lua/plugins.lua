local packer = nil
local function init()
    if packer == nil then
        packer = require('packer')
        packer.init {
            disable_commands = true
        } -- disable creating packer commands
    end

    local use = packer.use
    packer.reset()

    -- Packer
    use 'wbthomason/packer.nvim'

    -- -- use 'lewis6991/impatient.nvim'

    -- Color scheme
    use 'sainnhe/gruvbox-material'
    -- use 'joshdick/onedark.vim'
    -- use 'rakr/vim-one'

    use {
        'junegunn/rainbow_parentheses.vim',
        config = [[require('config.rainbow_parentheses')]]
    }
    -- use {'kyazdani42/nvim-web-devicons'}

    -- Undo tree
    use {
        'mbbill/undotree',
        config = [[require('config.undotree')]]
    }
    -- Tagbar
    use {
        'majutsushi/tagbar',
        config = [[require('config.tagbar')]]
    }

    use {
        'nvim-treesitter/nvim-treesitter',
        requires = {'nvim-treesitter/nvim-treesitter-textobjects'},
        config = [[require('config.treesitter')]],
        run = ':TSUpdate'
    }
    use 'nvim-treesitter/playground'

    -- Completion
    use {{
        'neovim/nvim-lspconfig',
        config = [[require('config.lsp_config')]]
    }, -- 'onsails/lspkind-nvim', -- adds vscode-like pictograms
    {
        'kosayoda/nvim-lightbulb',
        config = function()
            vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()]]
        end
    }, {
        -- Autocompletion plugin
        'hrsh7th/nvim-cmp',
        requires = {'hrsh7th/cmp-nvim-lsp', {
            'hrsh7th/cmp-buffer',
            after = 'nvim-cmp'
        }, {
            'hrsh7th/cmp-path',
            after = 'nvim-cmp'
        }, {
            'hrsh7th/cmp-nvim-lua',
            after = 'nvim-cmp'
        }, {
            'L3MON4D3/LuaSnip',
            config = [[require('config.luasnip')]]
        }, -- Snippets plugin
        {
            'saadparwaiz1/cmp_luasnip',
            after = 'nvim-cmp'
        }},
        config = [[require('config.cmp')]],
        event = 'InsertEnter *'
    }, {"ray-x/lsp_signature.nvim"} -- {'rafamadriz/friendly-snippets'}, -- Snippets collection
    }

    use {
        'github/copilot.vim',
        config = function()
            vim.cmd [[
            imap <silent><script><expr> <C-L> copilot#Accept("\<right>")
            let g:copilot_no_tab_map = v:true
            ]]
        end
    }

    -- use 'nvim-lua/lsp-status.nvim'

    use {
        "folke/trouble.nvim",
        -- requires = "nvim-web-devicons",
        config = [[require('config.trouble')]]
    }

    -- -- Debugger
    -- -- use {{
    -- --     'mfussenegger/nvim-dap',
    -- --     setup = [[require('config.dap_setup')]],
    -- --     config = [[require('config.dap')]],
    -- --     requires = 'jbyuki/one-small-step-for-vimkind',
    -- --     wants = 'one-small-step-for-vimkind',
    -- --     module = 'dap'
    -- -- }, {
    -- --     'rcarriga/nvim-dap-ui',
    -- --     requires = 'nvim-dap',
    -- --     after = 'nvim-dap',
    -- --     config = function()
    -- --         require('dapui').setup()
    -- --     end
    -- -- }}

    -- Search  
    use {
        'nvim-telescope/telescope.nvim',
        requires = {'nvim-lua/plenary.nvim', 'telescope-fzf-native.nvim' -- , {'telescope-frecency.nvim'}
        },
        setup = [[require('config.telescope_setup')]],
        config = [[require('config.telescope')]]
    }
    use {
        'nvim-telescope/telescope-fzf-native.nvim',
        run = 'make'
    }
    -- use {
    --     "nvim-telescope/telescope-frecency.nvim",
    --     config = function()
    --         require"telescope".load_extension("frecency")
    --     end,
    --     requires = {"tami5/sqlite.lua"}
    -- }
    -- use {
    --     'edolphin-ydf/goimpl.nvim',
    --     requires = {{'nvim-telescope/telescope.nvim'}, {'nvim-treesitter/nvim-treesitter'}},
    --     config = function()
    --         require'telescope'.load_extension 'goimpl'
    --         vim.api.nvim_set_keymap('n', '<leader>im', [[<cmd>lua require'telescope'.extensions.goimpl.goimpl{}<CR>]], {
    --             noremap = true,
    --             silent = true
    --         })

    --     end
    -- }

    -- Git
    use {{
        'TimUntersberger/neogit',
        requires = 'nvim-lua/plenary.nvim',
        config = function()
            require('neogit').setup({
                disable_signs = false
            })
        end
    }, {
        'lewis6991/gitsigns.nvim',
        requires = {'nvim-lua/plenary.nvim'},
        config = [[require('config.gitsigns')]]
    }}
    -- use {
    --     'sindrets/diffview.nvim',
    --     requires = 'nvim-lua/plenary.nvim'
    -- }

    -- -- Profiling
    use {
        'dstein64/vim-startuptime',
        cmd = 'StartupTime',
        config = [[vim.g.startuptime_tries = 10]]
    }

    -- Comment
    -- use {
    --     'numToStr/Comment.nvim',
    --     config = function()
    --         require('config.comment')
    --     end
    -- }
    use {
        'tpope/vim-commentary',
        config = [[require('config.vim-commentary')]]
    }
    -- use 'JoosepAlviste/nvim-ts-context-commentstring'

    -- use 'tpope/vim-repeat'
    use 'tpope/vim-surround'
    -- use 'tpope/vim-abolish'
    -- use 'tpope/vim-endwise'

    use {
        'tpope/vim-rsi',
        config = function()
            vim.g.rsi_no_meta = 1
        end
    }

    use {
        'windwp/nvim-autopairs',
        config = [[require('config.autopairs')]]
    }

    -- use {
    --     "danymat/neogen",
    --     config = [[require('config.neogen')]],
    --     requires = "nvim-treesitter/nvim-treesitter"
    -- }

    -- markdown preview
    -- use {
    --     "ellisonleao/glow.nvim",
    --     config = function()
    --         vim.g.glow_binary_path = vim.env.HOME .. "/bin"
    --     end
    -- }

    -- -- Go dev
    -- use {
    --     'fatih/vim-go',
    --     run = ':GoUpdateBinaries',
    --     config = [[require('config.vim-go')]]
    -- }
    -- use {
    --     'ray-x/go.nvim',
    --     config = [[require('go').setup()]]
    -- }

    -- -- Refactoring
    -- use {
    --     "ThePrimeagen/refactoring.nvim",
    --     requires = {{"nvim-lua/plenary.nvim"}, {"nvim-treesitter/nvim-treesitter"}}
    -- }

    -- -- template
    -- use 'mattn/vim-sonictemplate'

    -- -- Plugin development
    -- -- use 'folke/lua-dev.nvim'

    -- -- Quickfix
    -- -- use 'kevinhwang91/nvim-bqf'

    -- use {
    --     "max397574/better-escape.nvim",
    --     config = function()
    --         require("better_escape").setup()
    --     end
    -- }

end

local plugins = setmetatable({}, {
    __index = function(_, key)
        init()
        return packer[key]
    end
})

return plugins
