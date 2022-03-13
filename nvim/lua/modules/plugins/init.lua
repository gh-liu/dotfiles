local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
  PACKER_BOOTSTRAP = fn.system({
    "git",
    "clone",
    "--depth",
    "1",
    "https://github.com/wbthomason/packer.nvim",
    install_path,
  })
  print("Installing packer close and reopen Neovim...")
  vim.cmd([[packadd packer.nvim]])
end

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

-- Have packer use a popup window
packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = "rounded" })
    end,
  },
})

return require("packer").startup(function(use)
  local config = function(name)
    return string.format("require('modules.plugins.%s')", name)
  end

  -- Packer
  use("wbthomason/packer.nvim")
  -- NOTE: this is plugin is unnecessary once https://github.com/neovim/neovim/pull/15436 is merged
  use({ "lewis6991/impatient.nvim" })

  -- required by other plugins
  use({
    { "nvim-lua/popup.nvim" },
    { "nvim-lua/plenary.nvim" },
  })

  -- ====== UI ======
  -- schemes
  use("sainnhe/gruvbox-material")

  -- Donwload a patched font and install it first(https://github.com/ryanoasis/nerd-fonts)
  use({ "kyazdani42/nvim-web-devicons" })

  -- ====== Treesitter ======
  use({
    "nvim-treesitter/nvim-treesitter",
    requires = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "nvim-treesitter/nvim-treesitter-refactor",
    },
    config = config("treesitter"),
    run = ":TSUpdate",
  })
  use({
    "nvim-treesitter/playground",
  })
  use("p00f/nvim-ts-rainbow")

  -- ====== Telescope ======
  use({
    "nvim-telescope/telescope.nvim",
    requires = {
      "telescope-fzf-native.nvim",
    },
    setup = config("telescope-setup"),
    config = config("telescope"),
  })
  use({
    "nvim-telescope/telescope-fzf-native.nvim",
    run = "make",
  })
  use({
    "nvim-telescope/telescope-file-browser.nvim",
    config = config("telescope-file-browser"),
  })

  use({
    "gh-liu/goimpl.nvim",
    requires = {
      { "nvim-telescope/telescope.nvim" },
      { "nvim-treesitter/nvim-treesitter" },
    },
    config = config("goimpl"),
  })

  -- ====== Coding ======
  -- LSP
  use({
    "neovim/nvim-lspconfig",
  })
  use({ "onsails/lspkind-nvim" })
  use({
    "kosayoda/nvim-lightbulb",
    config = config("nvim-lightbulb"),
  })
  use({
    "j-hui/fidget.nvim",
    config = config("fidget"),
  })

  --  Autocompletion
  use({
    "hrsh7th/nvim-cmp",
    requires = {
      "hrsh7th/cmp-nvim-lsp",
      {
        "hrsh7th/cmp-buffer",
        after = "nvim-cmp",
      },
      {
        "hrsh7th/cmp-path",
        after = "nvim-cmp",
      },
      {
        "hrsh7th/cmp-nvim-lua",
        after = "nvim-cmp",
      },
      {
        "L3MON4D3/LuaSnip",
        config = config("luasnip"),
      },
      {
        -- Snippets plugin
        "saadparwaiz1/cmp_luasnip",
        after = "nvim-cmp",
      },
    },
    config = config("cmp"),
  })
  use("hrsh7th/cmp-cmdline")
  use({ "rafamadriz/friendly-snippets" })

  -- Copilot
  use({
    "github/copilot.vim",
    config = function()
      vim.cmd([[
              imap <silent><script><expr> <C-L> copilot#Accept("\<right>")
              let g:copilot_no_tab_map = v:true
              let g:copilot_filetypes = {
                \ 'TelescopePrompt': v:false,
                \ }
              ]])
    end,
  })

  -- Comment
  -- use({
  --   "tpope/vim-commentary",
  --   config = config("vim-commentary"),
  -- })
  use({
    "numToStr/Comment.nvim",
    config = config("comment"),
  })

  -- Annotation generator
  use({
    "danymat/neogen",
    config = config("neogen"),
    requires = "nvim-treesitter/nvim-treesitter",
  })

  -- Refactoring
  -- use({
  -- 	"ThePrimeagen/refactoring.nvim",
  -- 	requires = { { "nvim-treesitter/nvim-treesitter" } },
  -- 	config = config("refactoring"),
  -- })

  -- Undo tree
  -- use({
  --   "mbbill/undotree",
  --   config = config("undotree"),
  -- })

  -- Tagbar
  use({
    "majutsushi/tagbar",
    config = config("tagbar"),
  })

  -- Autopair
  use({
    "windwp/nvim-autopairs",
    config = config("autopairs"),
  })

  -- ====== Moving ======
  -- use({
  --   "phaazon/hop.nvim",
  --   branch = "v1",
  --   config = config("hop"),
  -- })

  -- ====== Debug ======

  -- ====== Git ======
  use({
    {
      "TimUntersberger/neogit",
      config = config("neogit"),
    },
    {
      "lewis6991/gitsigns.nvim",
      config = config("gitsigns"),
    },
  })
  use({
    "sindrets/diffview.nvim",
    -- config = [[require('diffview').setup {use_icons = false}]],
  })

  -- ====== Language Specified ======
  -- Lua dev
  use("folke/lua-dev.nvim")

  -- Rust
  use("simrat39/rust-tools.nvim")

  -- Clojure dev
  -- use("Olical/conjure")

  -- -- markdown preview
  -- use({
  -- 	"ellisonleao/glow.nvim",
  -- 	config = function()
  -- 		vim.g.glow_binary_path = vim.env.HOME .. "/bin"
  -- 	end,
  -- })

  -- ====== Others ======
  -- Pretty colors
  use("norcalli/nvim-colorizer.lua")
  use({
    "norcalli/nvim-terminal.lua",
    config = function()
      require("terminal").setup()
    end,
  })

  -- use({
  --   "folke/zen-mode.nvim",
  --   enable = false,
  -- })

  use("editorconfig/editorconfig-vim")

  -- Profiling
  use({
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    config = [[vim.g.startuptime_tries = 10]],
  })

  use("tpope/vim-repeat")
  -- use("tpope/vim-surround")
  -- use("tpope/vim-eunuch")
  -- use("tpope/vim-endwise")
  -- use("tpope/vim-dispatch")

  -- provides Readline (Emacs) mappings for insert and command line mode
  -- also be required by tmux-plugins/tmux-yank
  use({
    "tpope/vim-rsi",
    config = function()
      vim.g.rsi_no_meta = 1
    end,
  })

  use({
    "folke/todo-comments.nvim",
    config = function()
      require("todo-comments").setup({})
    end,
  })

  -- use({
  --   "rcarriga/nvim-notify",
  --   config = config("nvim-notify"),
  -- })

  use({
    "antoinemadec/FixCursorHold.nvim",
    run = function()
      vim.g.curshold_updatime = 1000
    end,
  })

  use("milisims/nvim-luaref")

  -- Quickfix
  -- use("kevinhwang91/nvim-bqf")

  -- Quickfix enhancements. See :help vim-qf
  use("romainl/vim-qf")

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
