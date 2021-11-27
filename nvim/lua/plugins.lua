local packer = nil
local function init()
  if packer == nil then
    packer = require('packer')
    packer.init { disable_commands = true } -- disable creating packer commands
  end

  local use = packer.use
  packer.reset()

  -- Packer
  use 'wbthomason/packer.nvim'

  use 'lewis6991/impatient.nvim'

  use {
    'junegunn/rainbow_parentheses.vim',
    config = [[require('config.rainbow_parentheses')]],
  }

  -- Color scheme
  use 'sainnhe/gruvbox-material'
  -- use 'joshdick/onedark.vim'
  use 'rakr/vim-one'

  -- Undo tree
  use {
    'mbbill/undotree',
    -- cmd = 'UndotreeToggle',
    config = [[require('config.undotree')]],
  }

  use {
    'majutsushi/tagbar',
    -- cmd = 'TagbarToggle',
    config = [[require('config.tagbar')]],
  }

  -- Completion
  use {
    {
      'neovim/nvim-lspconfig',
      config = [[require('config.lsp_config')]],
    },
    -- 'onsails/lspkind-nvim', -- adds vscode-like pictograms
    -- 'kosayoda/nvim-lightbulb',
    {
      'hrsh7th/nvim-cmp',
      requires = {
        'hrsh7th/cmp-nvim-lsp',
        { 'hrsh7th/cmp-buffer', after = 'nvim-cmp' },
        { 'hrsh7th/cmp-path', after = 'nvim-cmp' },
        { 'hrsh7th/cmp-nvim-lua', after = 'nvim-cmp' },
        'L3MON4D3/LuaSnip', -- Snippets plugin
        { 'saadparwaiz1/cmp_luasnip', after = 'nvim-cmp' },
      },
      config = [[require('config.cmp')]],
      event = 'InsertEnter *',
    }, -- Autocompletion plugin
  }

  use {
    "folke/trouble.nvim",
    -- requires = "kyazdani42/nvim-web-devicons",
    config = function()
      require('trouble').setup({
        icons = false,
        fold_open = "-", -- icon used for open folds
        fold_closed = "+", -- icon used for closed folds
        indent_lines = false, -- add an indent guide below the fold icons
        signs = {
            -- icons / text used for a diagnostic
            error = "error",
            warning = "warn",
            hint = "hint",
            information = "info"
        },
        use_lsp_diagnostic_signs = true -- enabling this will use the signs defined in your lsp client
    })
    vim.api.nvim_set_keymap('n', '<leader>t', '<cmd>TroubleToggle<cr>', {silent = true})
    end
  }

  use {
    "ray-x/lsp_signature.nvim",
    config = function()
      require('lsp_signature').setup()
    end
  }

  use {
    'windwp/nvim-autopairs',
    config = function()
      require('nvim-autopairs').setup{}
    end
  }

  -- use 'tpope/vim-repeat'
  -- use 'tpope/vim-surround'
  -- use 'tpope/vim-abolish'
  -- use 'tpope/vim-endwise'

  -- Comment
  use {
    'numToStr/Comment.nvim',
    config = function()
        require('Comment').setup()
    end
  }

  use {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate'
  }

  use { 
    "danymat/neogen", 
    config = [[require('config.neogen')]],
    requires = "nvim-treesitter/nvim-treesitter"
  }

  -- Git
  use {
    -- { 'tpope/vim-fugitive', cmd = { 'Git' } },
    { 
      'TimUntersberger/neogit', 
      requires = 'nvim-lua/plenary.nvim', 
      config = function()
        require('neogit').setup({disable_signs = false,})
      end
    },
    {
      'lewis6991/gitsigns.nvim',
      requires = { 'nvim-lua/plenary.nvim' },
      config = [[require('config.gitsigns')]],
    },
  }

  -- Search  
  use {
    'nvim-telescope/telescope.nvim',
    requires = { 
      'nvim-lua/plenary.nvim', 
      'telescope-fzf-native.nvim',
      -- 'telescope-frecency.nvim',
     },
    setup = [[require('config.telescope_setup')]],
    config = [[require('config.telescope')]],
  }
  use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
  -- use {
  --   "nvim-telescope/telescope-frecency.nvim",
  --   after = 'telescope.nvim',
  --   requires = {"tami5/sqlite.lua"}
  -- }

  -- use 'github/copilot.vim'

  -- Profiling
  -- use { 'dstein64/vim-startuptime', cmd = 'StartupTime', config = [[vim.g.startuptime_tries = 10]] }

  -- Go dev
  use {'fatih/vim-go', run = ':GoUpdateBinaries',config = [[require('config.vim-go')]]}


  -- Refactoring
  -- use { 'ThePrimeagen/refactoring.nvim', opt = true }

  -- Plugin development
  -- use 'folke/lua-dev.nvim'

  -- Quickfix
  use 'kevinhwang91/nvim-bqf'

  -- Debugger
  use {
    {
      'mfussenegger/nvim-dap',
      setup = [[require('config.dap_setup')]],
      config = [[require('config.dap')]],
      requires = 'jbyuki/one-small-step-for-vimkind',
      wants = 'one-small-step-for-vimkind',
      module = 'dap',
    },
    {
      'rcarriga/nvim-dap-ui',
      requires = 'nvim-dap',
      after = 'nvim-dap',
      config = function()
        require('dapui').setup()
      end,
    },
  }
  
end

local plugins = setmetatable({}, {
  __index = function(_, key)
    init()
    return packer[key]
  end,
})

return plugins
