-- :help conform-formatters
local formatters_by_ft = {
	go = {
		-- "goimports",
		"gofmt",
		-- "gofumpt",
	},
	lua = {
		"stylua",
	},
	rust = {
		"rustfmt",
	},
	-- zig = {
	-- 	"zigfmt",
	-- },
	python = {
		"ruff_format",
		"ruff_organize_imports",
		-- "isort",
		-- "black",
	},
	json = {
		"jq",
	},
	yaml = {
		"yamlfmt",
	},
	toml = {
		"taplo",
	},
	sh = {
		"shfmt",
	},
	zsh = {
		"shfmt",
	},
	just = { "just" },
	proto = { "buf" },
	query = { "format-queries" },
	javascript = { "oxfmt" },
	typescript = { "oxfmt" },
	markdown = { "injected" },
	sql = { "sqlfluff" },
	terraform = { "terraform_fmt" },
}

return {
	-- Lightweight formatter with 100+ formatters, preserving extmarks and folds
	"stevearc/conform.nvim",
	lazy = true,
	init = function(self)
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
	keys = {
		{
			"yoF",
			function()
				if (not vim.g.EnableAutoFormat) or vim.g.EnableAutoFormat == 0 then
					vim.g.EnableAutoFormat = 1
					vim.notify("Enable autoformat", vim.log.levels.WARN)
				else
					vim.g.EnableAutoFormat = 0
					vim.notify("Disable autoformat", vim.log.levels.WARN)
				end
			end,
			desc = "Toggle autoformat",
		},
	},
	ft = function(self, ft)
		return vim.tbl_keys(self.opts.formatters_by_ft)
	end,
	opts = {
		-- :help conform-formatters
		formatters_by_ft = formatters_by_ft,
		default_format_opts = {
			lsp_format = "fallback",
		},
		format_on_save = function(bufnr)
			if vim.g.EnableAutoFormat == 1 or vim.b[bufnr].EnableAutoFormat == 1 then
				return {
					timeout_ms = 500,
					lsp_format = "fallback",
				}
			end
		end,
	},
	config = function(self, opts)
		require("conform").setup(opts)

		require("conform").formatters.sqlfluff = function(bufnr)
			local dialect = vim.b[bufnr].sql_dialect or vim.b.sql_type_override or vim.g.sql_type_default
			if dialect then
				return {
					args = {
						"fix",
						"--dialect",
						dialect,
						"-",
					},
					require_cwd = false,
				}
			end
		end
	end,
}
