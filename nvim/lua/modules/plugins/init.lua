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

  use("wbthomason/packer.nvim")

  -- NOTE: this is plugin is unnecessary once https://github.com/neovim/neovim/pull/15436 is merged
  use({ "lewis6991/impatient.nvim" })

  -- required by other plugins
  use({
    { "nvim-lua/popup.nvim" },
    { "nvim-lua/plenary.nvim" },
  })

  -- ====== Notification ======
  use({
    "rcarriga/nvim-notify",
    config = config("nvim-notify"),
  })

  -- ====== UI ======
  -- schemes
  use({ "catppuccin/nvim" })
  use({ "Mofiqul/vscode.nvim" })
  use({ "ellisonleao/gruvbox.nvim" })
  use({ "projekt0n/github-nvim-theme" })
  -- winbar
  use({
    "SmiteshP/nvim-navic",
  })

  -- Donwload a patched font and install it first(https://github.com/ryanoasis/nerd-fonts)
  use({ "kyazdani42/nvim-web-devicons" })

  use({ "rebelot/heirline.nvim", config = config("heirline") })

  -- ====== Treesitter ======
  use({
    "nvim-treesitter/nvim-treesitter",
    config = config("treesitter"),
    run = ":TSUpdate",
  })
  use({
    "nvim-treesitter/playground",
  })
  use({
    "nvim-treesitter/nvim-treesitter-refactor",
  })
  use({
    "nvim-treesitter/nvim-treesitter-textobjects",
  })
  use("p00f/nvim-ts-rainbow")
  use("theHamsta/nvim-treesitter-pairs")

  -- ====== Telescope ======
  use({
    "nvim-telescope/telescope.nvim",
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
  -- use({ "nvim-telescope/telescope-github.nvim" })
  use({ "nvim-telescope/telescope-ui-select.nvim" })

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
  use({ "jose-elias-alvarez/null-ls.nvim", config = config("nullls") })
  -- use({ "onsails/lspkind-nvim", event = "BufRead" })
  use({
    "j-hui/fidget.nvim",
    config = config("fidget"),
  })
  use({ "aspeddro/lsp_menu.nvim" })
  use({
    "kosayoda/nvim-lightbulb",
    config = function()
      -- vim.fn.sign_define('LightBulbSign', { text = "↑", texthl = "", linehl = "", numhl = "" })
      require("nvim-lightbulb").setup({ autocmd = { enabled = true } })
    end,
  })

  --  Autocompletion
  use({
    "hrsh7th/nvim-cmp",
    requires = {},
    config = config("cmp"),
  })
  use({
    "hrsh7th/cmp-nvim-lsp",
    after = "nvim-cmp",
  })
  use({ "hrsh7th/cmp-nvim-lsp-signature-help" })
  use({
    "hrsh7th/cmp-buffer",
    after = "nvim-cmp",
  })
  use({
    "hrsh7th/cmp-path",
    after = "nvim-cmp",
  })
  use({
    "hrsh7th/cmp-nvim-lua",
    after = "nvim-cmp",
  })
  use({ "hrsh7th/cmp-cmdline" })
  use({
    -- Snippets plugin
    "saadparwaiz1/cmp_luasnip",
    after = "nvim-cmp",
  })
  use({
    "L3MON4D3/LuaSnip",
    config = config("luasnip"),
  })
  use({ "rafamadriz/friendly-snippets" })

  -- Comment
  use({
    "numToStr/Comment.nvim",
    config = config("comment"),
  })

  -- ====== Debug ======
  use({
    "mfussenegger/nvim-dap",
    -- config = config("dap"),
  })
  use({
    "rcarriga/nvim-dap-ui",
    config = config("dapui"),
  })
  use("nvim-telescope/telescope-dap.nvim")

  -- Undo tree
  -- use({
  --   "mbbill/undotree",
  --   config = config("undotree"),
  -- })

  use({
    "simrat39/symbols-outline.nvim",
    config = config("symbols-outline"),
  })

  -- Autopair
  use({
    "windwp/nvim-autopairs",
    config = config("autopairs"),
  })

  -- ====== Moving ======
  use({
    "phaazon/hop.nvim",
    branch = "v2",
    config = config("hop"),
  })

  -- ====== Git ======
  use({
    "TimUntersberger/neogit",
    config = config("neogit"),
  })
  use({
    "sindrets/diffview.nvim",
  })
  use({
    "lewis6991/gitsigns.nvim",
    config = config("gitsigns"),
  })

  -- ====== Language Specified ======
  -- Lua dev
  use("folke/lua-dev.nvim")
  use("milisims/nvim-luaref")
  use("bfredl/nvim-luadev")

  -- Rust
  -- use("simrat39/rust-tools.nvim")

  -- ====== Others ======
  -- Pretty colors
  use({
    "norcalli/nvim-colorizer.lua",
    -- cmd = { "ColorizerAttachToBuffer", "ColorizerToggle" },
    event = "BufRead",
    config = function()
      require("colorizer").setup()
    end,
  })

  -- use("editorconfig/editorconfig-vim")

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

  -- Annotation generator
  -- use({
  --   "danymat/neogen",
  --   config = config("neogen"),
  --   requires = "nvim-treesitter/nvim-treesitter",
  -- })

  use({
    "antoinemadec/FixCursorHold.nvim",
    run = function()
      vim.g.curshold_updatime = 1000
    end,
  })

  -- use({
  --   "max397574/better-escape.nvim",
  --   config = function()
  --     require("better_escape").setup()
  --   end,
  -- })

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)
