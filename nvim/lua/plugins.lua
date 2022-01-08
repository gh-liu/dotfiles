local packer = nil

local function init()
  if packer == nil then
    packer = require("packer")
    packer.init({
      -- disable creating packer commands
      disable_commands = true,
    })
  end

  local use = packer.use
  packer.reset()

  -- Packer
  use("wbthomason/packer.nvim")

  -- use {'lewis6991/impatient.nvim'}

  -- ====== UI ======
  -- schemes
  use("sainnhe/gruvbox-material")
  -- use("joshdick/onedark.vim")
  -- use("rakr/vim-one")

  -- use({
  -- 	"junegunn/rainbow_parentheses.vim",
  -- 	config = [[require('config.rainbow_parentheses')]],
  -- })
  -- Donwload a patched font and install it first(https://github.com/ryanoasis/nerd-fonts)
  use({ "kyazdani42/nvim-web-devicons" })

  -- ====== Telescope ======
  use({
    "nvim-telescope/telescope.nvim",
    requires = {
      "nvim-lua/plenary.nvim",
      "telescope-fzf-native.nvim",
    },
    setup = [[require('config.telescope_setup')]],
    config = [[require('config.telescope')]],
  })
  use({
    "nvim-telescope/telescope-fzf-native.nvim",
    run = "make",
  })
  -- use("nvim-telescope/telescope-github.nvim")
  -- use({ "nvim-telescope/telescope-file-browser.nvim" })
  -- use({
  -- 	"nvim-telescope/telescope-frecency.nvim",
  -- 	config = function()
  -- 		require("telescope").load_extension("frecency")
  -- 	end,
  -- 	requires = { "tami5/sqlite.lua" },
  -- })
  -- use({
  -- 	"edolphin-ydf/goimpl.nvim",
  -- 	requires = { { "nvim-telescope/telescope.nvim" }, { "nvim-treesitter/nvim-treesitter" } },
  -- 	config = function()
  -- 		require("telescope").load_extension("goimpl")
  -- 		vim.api.nvim_set_keymap("n", "<leader>im", [[<cmd>lua require'telescope'.extensions.goimpl.goimpl{}<CR>]], {
  -- 			noremap = true,
  -- 			silent = true,
  -- 		})
  -- 	end,
  -- })

  -- ====== Treesitter ======
  use({
    "nvim-treesitter/nvim-treesitter",
    requires = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "nvim-treesitter/nvim-treesitter-refactor",
    },
    config = [[require('config.treesitter')]],
    run = ":TSUpdate",
  })
  -- use("nvim-treesitter/playground")
  -- use("nvim-treesitter/nvim-tree-docs")
  use("p00f/nvim-ts-rainbow")
  -- use("romgrk/nvim-treesitter-context")

  -- ====== Coding ======
  -- LSP
  use({
    "neovim/nvim-lspconfig",
    config = [[require('config.lsp_config')]],
  })
  use({ "onsails/lspkind-nvim" })
  -- use("nvim-lua/lsp-status.nvim")
  -- use({ "ray-x/lsp_signature.nvim" })
  use({
    "kosayoda/nvim-lightbulb",
    config = function()
      vim.fn.sign_define(
        "LightBulbSign",
        { text = "∆", texthl = "", linehl = "", numhl = "" }
      )
      vim.cmd(
        [[autocmd CursorHold,CursorHoldI * lua require('nvim-lightbulb').update_lightbulb()]]
      )
    end,
  })
  -- use("arkav/lualine-lsp-progress")
  -- use({
  -- 	"simrat39/symbols-outline.nvim",
  -- 	setup = function()
  -- 		vim.g.symbols_outline = {
  -- 			position = "left",
  -- 		}
  -- 	end,
  -- 	config = function()
  -- 		require("config.symbols-outline")
  -- 	end,
  -- })
  -- use({
  -- 	"folke/trouble.nvim",
  -- 	-- requires = "nvim-web-devicons",
  -- 	config = [[require('config.trouble')]],
  -- })

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
        config = [[require('config.luasnip')]],
      },
      {
        -- Snippets plugin
        "saadparwaiz1/cmp_luasnip",
        after = "nvim-cmp",
      },
    },
    config = [[require('config.cmp')]],
    -- event = "InsertEnter *",
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
            ]])
    end,
  })

  -- Comment
  -- use({
  -- 	"numToStr/Comment.nvim",
  -- 	config = function()
  -- 		require("config.comment")
  -- 	end,
  -- })
  use({
    "tpope/vim-commentary",
    config = [[require('config.vim-commentary')]],
  })
  -- use("JoosepAlviste/nvim-ts-context-commentstring")

  -- Refactoring
  -- use({
  -- 	"ThePrimeagen/refactoring.nvim",
  -- 	requires = { { "nvim-lua/plenary.nvim" }, { "nvim-treesitter/nvim-treesitter" } },
  -- 	config = [[require('config.refactoring')]],
  -- })

  -- Undo tree
  use({
    "mbbill/undotree",
    config = [[require('config.undotree')]],
  })

  -- Tagbar
  use({
    "majutsushi/tagbar",
    config = [[require('config.tagbar')]],
  })

  -- Autopair
  use({
    "windwp/nvim-autopairs",
    config = [[require('config.autopairs')]],
  })

  -- ====== Moving ======
  use({
    "phaazon/hop.nvim",
    branch = "v1",
    config = [[require('config.hop')]],
  })

  -- ====== Debug ======
  -- use({
  -- 	{
  -- 		"mfussenegger/nvim-dap",
  -- 		setup = [[require('config.dap_setup')]],
  -- 		config = [[require('config.dap')]],
  -- 		requires = "jbyuki/one-small-step-for-vimkind",
  -- 		wants = "one-small-step-for-vimkind",
  -- 		module = "dap",
  -- 	},
  -- 	{
  -- 		"rcarriga/nvim-dap-ui",
  -- 		requires = "nvim-dap",
  -- 		after = "nvim-dap",
  -- 		config = function()
  -- 			require("dapui").setup()
  -- 		end,
  -- 	},
  -- })

  -- ====== Git ======
  use({
    {
      "TimUntersberger/neogit",
      requires = "nvim-lua/plenary.nvim",
      config = [[require('config.neogit')]],
    },
    {
      "lewis6991/gitsigns.nvim",
      requires = { "nvim-lua/plenary.nvim" },
      config = [[require('config.gitsigns')]],
    },
  })
  use({
    "sindrets/diffview.nvim",
    requires = "nvim-lua/plenary.nvim",
    -- config = [[require('diffview').setup {use_icons = false}]],
  })

  -- ====== Language Specified ======
  -- -- Go dev
  -- use({
  -- 	"fatih/vim-go",
  -- 	run = ":GoUpdateBinaries",
  -- 	config = [[require('config.vim-go')]],
  -- })
  -- use({
  -- 	"ray-x/go.nvim",
  -- 	config = [[require('go').setup()]],
  -- })

  -- Lua dev
  -- use("folke/lua-dev.nvim")
  use("ckipp01/stylua-nvim")

  -- -- markdown preview
  -- use({
  -- 	"ellisonleao/glow.nvim",
  -- 	config = function()
  -- 		vim.g.glow_binary_path = vim.env.HOME .. "/bin"
  -- 	end,
  -- })

  -- ====== Others ======
  use("editorconfig/editorconfig-vim")

  -- Profiling
  -- use({
  -- 	"dstein64/vim-startuptime",
  -- 	cmd = "StartupTime",
  -- 	config = [[vim.g.startuptime_tries = 10]],
  -- })

  use("tpope/vim-repeat")
  -- use("tpope/vim-surround")
  -- use("tpope/vim-eunuch")
  -- use("tpope/vim-endwise")

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
    requires = "nvim-lua/plenary.nvim",
    config = function()
      require("todo-comments").setup({})
    end,
  })

  -- use({
  -- 	"danymat/neogen",
  -- 	config = [[require('config.neogen')]],
  -- 	requires = "nvim-treesitter/nvim-treesitter",
  -- })

  -- template
  -- use("mattn/vim-sonictemplate")

  -- Quickfix
  -- use("kevinhwang91/nvim-bqf")
end

local plugins = setmetatable({}, {
  __index = function(_, key)
    init()
    return packer[key]
  end,
})

return plugins
