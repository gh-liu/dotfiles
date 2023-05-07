local ok, _ = pcall(require, "nvim-treesitter")
if not ok then
	return
end
require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"c",
		"lua",
		"vim",
		"vimdoc",
		"comment",
		"go",
		"gosum",
		"gomod",
		"gowork",
		"rust",
		"bash",
		"regex",
		"diff",
		"gitignore",
		"gitcommit",
		"git_rebase",
	},
	sync_install = false,
	auto_install = true,
	highlight = {
		enable = true,
		-- Disable slow treesitter highlight for large files
		disable = function(lang, buf)
			local max_filesize = 100 * 1024 -- 100 KB
			local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
			if ok and stats and stats.size > max_filesize then
				return true
			end
		end,
	},
	indent = { enable = true },
	incremental_selection = {
		enable = false,
		keymaps = {
			-- init_selection = "<cr>",
			-- node_incremental = "<tab>",
			-- node_decremental = "<s-tab>",
			-- scope_incremental = "<cr>",
			-- scope_decremental = "<s-cr>",
		},
	},
	refactor = {
		smart_rename = {
			enable = true,
			keymaps = { smart_rename = "<leader>rn" }, -- override by lsp on LspAttach event
		},
		highlight_definitions = { enable = false },
		highlight_current_scope = { enable = false },
		navigation = {
			enable = false,
			keymaps = {
				-- goto_definition = "gnd",
				-- list_definitions = "gnD",
				-- list_definitions_toc = "gO",
				-- goto_next_usage = "<c-n>",
				-- goto_previous_usage = "<c-p>",
			},
		},
	},
	textobjects = {
		select = {
			enable = true,
			lookahead = false,
			keymaps = {
				["af"] = { query = "@function.outer", desc = "Select outer part of a function region" },
				["if"] = { query = "@function.inner", desc = "Select inner part of a function region" },

				["ac"] = { query = "@class.outer", desc = "Select outer part of a class region" },
				["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },

				["aB"] = { query = "@block.outer", desc = "Select outer part of a block region" },
				["iB"] = { query = "@block.inner", desc = "Select inner part of a block region" },

				-- ["aa"] = { query = "@parameter.outer", desc = "Select outer part of a parameter region" },
				-- ["ia"] = { query = "@parameter.inner", desc = "Select inner part of a parameter region" },
			},
			-- selection_modes = {},
			-- include_surrounding_whitespace = false,
		},
		move = {
			enable = true,
			set_jumps = true,
			goto_next_start = {},
			goto_next_end = {},
			goto_previous_start = {},
			goto_previous_end = {},
			-- Below will go to either the start or the end, whichever is closer.
			goto_next = {
				["]]"] = { query = "@function.outer", desc = "Next function" },
			},
			goto_previous = {
				["[["] = { query = "@function.outer", desc = "Prev function" },
			},
		},
		swap = { enable = false },
		lsp_interop = { enable = false },
	},
})

local group = vim.api.nvim_create_augroup("UserTreesitterFold", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
	pattern = {
		"go",
		"rust",
		"lua",
		"dosini",
		"json",
		"yaml",
		"markdown",
	},
	-- callback = function()
	-- end,
	command = "setl foldlevel=9 | setl foldmethod=expr | setl foldexpr=nvim_treesitter#foldexpr()",
	group = group,
	desc = "Set fold options",
})

vim.api.nvim_create_autocmd({ "BufRead" }, {
	pattern = { "*" },
	-- callback = function()
	-- end,
	command = "normal zx",
	group = group,
	desc = "Update folds when starting to edit a new buffer",
})
