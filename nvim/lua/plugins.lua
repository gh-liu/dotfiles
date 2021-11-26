local packer = nil
local function init()
  if packer == nil then
    packer = require 'packer'
    packer.init { disable_commands = true }
  end

  local use = packer.use
  packer.reset()

  use 'lewis6991/impatient.nvim'

  -- Undo tree
  use {
    'mbbill/undotree',
    cmd = 'UndotreeToggle',
    config = [[vim.g.undotree_SetFocusWhenToggle = 1]],
  }

  -- Git
  use {
    { 'tpope/vim-fugitive', cmd = { 'Git', 'Gstatus', 'Gblame', 'Gpush', 'Gpull' }, disable = true },
    {
      'lewis6991/gitsigns.nvim',
      requires = { 'nvim-lua/plenary.nvim' },
      config = [[require('config.gitsigns')]],
    },
    { 'TimUntersberger/neogit', cmd = 'Neogit', config = [[require('config.neogit')]] },
  }

  -- Completion and linting
  use {
    'onsails/lspkind-nvim',
    'neovim/nvim-lspconfig',
    'folke/trouble.nvim',
    'ray-x/lsp_signature.nvim',
    'kosayoda/nvim-lightbulb',
  }

  -- Endwise
  use 'tpope/vim-endwise'

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

  -- Color scheme
  use 'sainnhe/gruvbox-material'

end

local plugins = setmetatable({}, {
  __index = function(_, key)
    init()
    return packer[key]
  end,
})

return plugins
