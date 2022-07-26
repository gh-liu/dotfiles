local fn = vim.fn

-----------------------------------------------------------------------------//
-- Automatically install packer {{{
-----------------------------------------------------------------------------//
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
-- }}}

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
  return
end

local config = gh.lazy_require("core.config")

-- Have packer use a popup window
packer.init({
  display = {
    open_fn = function()
      return require("packer.util").float({ border = config.border.rounded })
    end,
  },
})

return require("packer").startup(function(use)
  local require_conf = function(name)
    return string.format("require('modules.plugins.%s')", name)
  end

  use("wbthomason/packer.nvim")
  -- NOTE: this is plugin is unnecessary once https://github.com/neovim/neovim/pull/15436 is merged
  use({ "lewis6991/impatient.nvim" })

  -----------------------------------------------------------------------------//
  -- libs {{{1
  -----------------------------------------------------------------------------//
  use({
    { "nvim-lua/popup.nvim" },
    { "nvim-lua/plenary.nvim" },
  })
  -- }}}
  -----------------------------------------------------------------------------//
  -- UI {{{1
  -----------------------------------------------------------------------------//
  -- schemes
  use({ "catppuccin/nvim" })
  use({ "Mofiqul/vscode.nvim" })
  use({ "ellisonleao/gruvbox.nvim" })
  use({ "projekt0n/github-nvim-theme" })
  -- winbar
  -- use({
  --   "SmiteshP/nvim-navic",
  -- })
  -- Donwload a patched font and install it first(https://github.com/ryanoasis/nerd-fonts)
  use({ "kyazdani42/nvim-web-devicons" })
  -- status line
  use({ "rebelot/heirline.nvim", config = require_conf("heirline") })
  use({
    "lukas-reineke/indent-blankline.nvim",
    event = "BufReadPre",
    cmd = { "IndentBlanklineToggle" },
  })
  -- }}}
  -----------------------------------------------------------------------------//
  -- tree-sitter {{{1
  -----------------------------------------------------------------------------//

  use({
    "nvim-treesitter/nvim-treesitter",
    config = require_conf("treesitter"),
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
  -- }}}
  -----------------------------------------------------------------------------//
  -- telescope {{{1
  -----------------------------------------------------------------------------//
  use({
    "nvim-telescope/telescope.nvim",
    config = require_conf("telescope"),
  })
  use({
    "nvim-telescope/telescope-fzf-native.nvim",
    run = "make",
  })
  use({
    "nvim-telescope/telescope-file-browser.nvim",
    config = require_conf("telescope-file-browser"),
  })
  -- use({ "nvim-telescope/telescope-github.nvim" })
  use({
    "nvim-telescope/telescope-ui-select.nvim",
    config = function()
      require("telescope").load_extension("ui-select")
    end,
  })
  use({
    "edolphin-ydf/goimpl.nvim",
    config = function()
      require("telescope").load_extension("goimpl")
      vim.keymap.set(
        "n",
        "<leader>im",
        require("telescope").extensions.goimpl.goimpl,
        {}
      )
    end,
  })

  -- }}}
  -----------------------------------------------------------------------------//
  -- lsp {{{1
  -----------------------------------------------------------------------------//
  use({
    "neovim/nvim-lspconfig",
  })
  use({ "jose-elias-alvarez/null-ls.nvim", config = require_conf("nullls") })
  -- use({
  --   "simrat39/symbols-outline.nvim",
  --   config = require_conf("symbols-outline"),
  -- })
  use({
    "stevearc/aerial.nvim",
    config = require_conf("aerial"),
  })
  use({
    "j-hui/fidget.nvim",
    config = require_conf("fidget"),
  })
  -- use({ "aspeddro/lsp_menu.nvim" })
  use({
    "weilbith/nvim-code-action-menu",
    config = require_conf("nvim-code-action-menu"),
  })
  use({
    "kosayoda/nvim-lightbulb",
    config = function()
      require("nvim-lightbulb").setup({ autocmd = { enabled = true } })
    end,
  })
  use({
    "lvimuser/lsp-inlayhints.nvim",
    config = require_conf("lsp-inlayhints"),
  })
  -- use({
  --   "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
  --   config = function()
  --     require("lsp_lines").setup()
  --   end,
  -- })
  -- use({
  --   "glepnir/lspsaga.nvim",
  --   branch = "main",
  --   config = config("lspsaga"),
  -- })
  -- }}}
  -----------------------------------------------------------------------------//
  -- completion {{{1
  -----------------------------------------------------------------------------//

  use({
    "hrsh7th/nvim-cmp",
    requires = {},
    config = require_conf("cmp"),
  })
  use({
    "hrsh7th/cmp-nvim-lsp",
    after = "nvim-cmp",
  })
  use({ "hrsh7th/cmp-nvim-lsp-signature-help" })
  -- use({ "hrsh7th/cmp-nvim-lsp-document-symbol" })
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
  use({ "dmitmel/cmp-cmdline-history" })
  use({
    -- Snippets plugin
    "saadparwaiz1/cmp_luasnip",
    after = "nvim-cmp",
  })
  use({
    "L3MON4D3/LuaSnip",
    config = require_conf("luasnip"),
  })
  use({ "rafamadriz/friendly-snippets" })
  -- }}}
  -----------------------------------------------------------------------------//
  -- dap {{{1
  -----------------------------------------------------------------------------//
  use({
    "mfussenegger/nvim-dap",
    -- config = config("dap"),
  })
  use({
    "rcarriga/nvim-dap-ui",
    config = require_conf("dapui"),
  })
  -- use("nvim-telescope/telescope-dap.nvim")
  -- }}}
  -----------------------------------------------------------------------------//
  -- git {{{1
  -----------------------------------------------------------------------------//
  use({
    "TimUntersberger/neogit",
    config = require_conf("neogit"),
  })
  use({
    "sindrets/diffview.nvim",
  })
  use({
    "lewis6991/gitsigns.nvim",
    config = require_conf("gitsigns"),
  })
  -- }}}
  -----------------------------------------------------------------------------//
  -- move {{{1
  -----------------------------------------------------------------------------//
  use({
    "phaazon/hop.nvim",
    branch = "v2",
    config = require_conf("hop"),
  })
  -- }}}
  -----------------------------------------------------------------------------//
  -- lang dev {{{1
  -----------------------------------------------------------------------------//
  -- Lua
  use({ "ii14/emmylua-nvim" })
  -- use("folke/lua-dev.nvim")
  use("milisims/nvim-luaref")
  use("bfredl/nvim-luadev")
  -- Rust
  use("simrat39/rust-tools.nvim")
  -- zig
  use("ziglang/zig.vim")
  -- }}}
  -----------------------------------------------------------------------------//
  -- misc {{{1
  -----------------------------------------------------------------------------//
  use({
    "rcarriga/nvim-notify",
    config = require_conf("nvim-notify"),
  })
  -- Pretty colors
  use({
    "norcalli/nvim-colorizer.lua",
    -- cmd = { "ColorizerAttachToBuffer", "ColorizerToggle" },
    event = "BufRead",
    config = function()
      require("colorizer").setup()
    end,
  })
  use({
    "numToStr/Comment.nvim",
    config = require_conf("comment"),
  })
  use({
    "windwp/nvim-autopairs",
    config = require_conf("autopairs"),
  })
  use({
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    config = [[vim.g.startuptime_tries = 10]],
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
  use({
    "kylechui/nvim-surround",
    config = function()
      require("nvim-surround").setup({})
    end,
  })
  use({
    "akinsho/toggleterm.nvim",
    tag = "v2.*",
    config = require_conf("toggleterm"),
  })
  -- use({
  --   "max397574/better-escape.nvim",
  --   config = function()
  --     require("better_escape").setup()
  --   end,
  -- })
  -- use({
  --   "mbbill/undotree",
  --   config = config("undotree"),
  -- })
  -- }}}
  -----------------------------------------------------------------------------//
  -- tpope {{{
  -----------------------------------------------------------------------------//
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
  -- }}}

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if PACKER_BOOTSTRAP then
    require("packer").sync()
  end
end)

-- vim:foldmethod=marker
