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
	-- Packer
	use("wbthomason/packer.nvim")
	-- NOTE: this is plugin is unnecessary once https://github.com/neovim/neovim/pull/15436 is merged
	use({ "lewis6991/impatient.nvim" })

	-- require by other plugins
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
		config = [[require('modules.plugins.treesitter')]],
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
		setup = [[require('modules.plugins.telescope-setup')]],
		config = [[require('modules.plugins.telescope')]],
	})
	use({
		"nvim-telescope/telescope-fzf-native.nvim",
		run = "make",
	})
	use({
		"nvim-telescope/telescope-file-browser.nvim",
		config = [[require('modules.plugins.telescope-file-browser')]],
	})

	use({
		"edolphin-ydf/goimpl.nvim",
		requires = {
			{ "nvim-telescope/telescope.nvim" },
			{ "nvim-treesitter/nvim-treesitter" },
		},
		config = function()
			require("telescope").load_extension("goimpl")
			vim.api.nvim_set_keymap("n", "<leader>im", [[<cmd>lua require('telescope').extensions.goimpl.goimpl{}<CR>]], {
				noremap = true,
				silent = true,
			})
		end,
	})

	-- ====== Coding ======
	-- LSP
	use({
		"neovim/nvim-lspconfig",
	})
	use({ "onsails/lspkind-nvim" })
	use({
		"kosayoda/nvim-lightbulb",
		config = function()
			vim.fn.sign_define("LightBulbSign", { text = "∆", texthl = "", linehl = "", numhl = "" })
			vim.cmd([[autocmd CursorHold,CursorHoldI * lua require('nvim-lightbulb').update_lightbulb()]])
		end,
	})
	use({
		"j-hui/fidget.nvim",
		config = function()
			require("fidget").setup({
				text = {
					spinner = "dots",
				},
			})
		end,
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
				config = [[require('modules.plugins.luasnip')]],
			},
			{
				-- Snippets plugin
				"saadparwaiz1/cmp_luasnip",
				after = "nvim-cmp",
			},
		},
		config = [[require('modules.plugins.cmp')]],
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
	use({
		"tpope/vim-commentary",
		config = [[require('modules.plugins.vim-commentary')]],
	})

	-- Refactoring
	-- use({
	-- 	"ThePrimeagen/refactoring.nvim",
	-- 	requires = { { "nvim-treesitter/nvim-treesitter" } },
	-- 	config = [[require('modules.plugins.refactoring')]],
	-- })

	-- Undo tree
	-- use({
	--   "mbbill/undotree",
	--   config = [[require('modules.plugins.undotree')]],
	-- })

	-- Tagbar
	use({
		"majutsushi/tagbar",
		config = [[require('modules.plugins.tagbar')]],
	})

	-- Autopair
	use({
		"windwp/nvim-autopairs",
		config = [[require('modules.plugins.autopairs')]],
	})

	-- ====== Moving ======
	-- use({
	--   "phaazon/hop.nvim",
	--   branch = "v1",
	--   config = [[require('modules.plugins.hop')]],
	-- })

	-- ====== Debug ======

	-- ====== Git ======
	use({
		{
			"TimUntersberger/neogit",
			config = [[require('modules.plugins.neogit')]],
		},
		{
			"lewis6991/gitsigns.nvim",
			config = [[require('modules.plugins.gitsigns')]],
		},
	})
	use({
		"sindrets/diffview.nvim",
		-- config = [[require('diffview').setup {use_icons = false}]],
	})

	-- ====== Language Specified ======
	-- Lua dev
	-- use("folke/lua-dev.nvim")
	use("ckipp01/stylua-nvim")

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
	use({
		"folke/zen-mode.nvim",
	})

	use("editorconfig/editorconfig-vim")

	-- Profiling
	use({
		"dstein64/vim-startuptime",
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

	-- Quickfix
	-- use("kevinhwang91/nvim-bqf")

	-- Automatically set up your configuration after cloning packer.nvim
	-- Put this at the end after all plugins
	if PACKER_BOOTSTRAP then
		require("packer").sync()
	end
end)
