local packer = nil
local function init()
  if packer == nil then
    packer = require 'packer'
    packer.init { disable_commands = true }
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
      config = [[require 'config.lsp_config']],
    },
    'onsails/lspkind-nvim', -- adds vscode-like pictograms
    'folke/trouble.nvim',
    'ray-x/lsp_signature.nvim',
    'kosayoda/nvim-lightbulb',
    {
      'hrsh7th/nvim-cmp',
      requires = {
        'hrsh7th/cmp-nvim-lsp',
        { 'hrsh7th/cmp-buffer', after = 'nvim-cmp' },
        { 'hrsh7th/cmp-path', after = 'nvim-cmp' },
        { 'hrsh7th/cmp-nvim-lua', after = 'nvim-cmp' },
        'L3MON4D3/LuaSnip', -- Snippets plugin
        { 'saadparwaiz1/cmp_luasnip', after = 'nvim-cmp' },
        -- 'SirVer/ultisnips',
      },
      config = [[require('config.cmp')]],
      event = 'InsertEnter *',
    }, -- Autocompletion plugin
  }

  use 'tpope/vim-repeat'
  use 'tpope/vim-surround'
  use 'tpope/vim-abolish'
  use 'tpope/vim-endwise'

  -- Comment
  use {
    'tpope/vim-commentary',
    config = [[require('config.commentary')]],
  }

  -- Git
  use {
    { 'tpope/vim-fugitive', cmd = { 'Git' } },
    {
      'lewis6991/gitsigns.nvim',
      requires = { 'nvim-lua/plenary.nvim' },
      config = [[require('config.gitsigns')]],
    },
  }
  
  -- Search
  use {
    {
      'nvim-telescope/telescope.nvim',
      requires = {
        'nvim-lua/popup.nvim',
        'nvim-lua/plenary.nvim',
        'telescope-frecency.nvim',
        'telescope-fzf-native.nvim',
      },
      -- wants = {
      --   'popup.nvim',
      --   'plenary.nvim',
      --   'telescope-frecency.nvim',
      --   'telescope-fzf-native.nvim',
      -- },
      setup = [[require('config.telescope_setup')]],
      config = [[require('config.telescope')]],
      cmd = 'Telescope',
      module = 'telescope',
    },
    {
      'nvim-telescope/telescope-frecency.nvim',
      after = 'telescope.nvim',
      requires = 'tami5/sql.nvim',
    },
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      run = 'make',
    },
  }

  -- use 'github/copilot.vim'
  
  -- Profiling
  use { 'dstein64/vim-startuptime', cmd = 'StartupTime', config = [[vim.g.startuptime_tries = 10]] }

  -- Go dev
  use {'fatih/vim-go', run = ':GoUpdateBinaries',config = [[require('config.vim-go')]]}

  -- use 'windwp/nvim-autopairs'

end

local plugins = setmetatable({}, {
  __index = function(_, key)
    init()
    return packer[key]
  end,
})

return plugins
