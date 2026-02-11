-- :help conform-formatters
local formatters_by_ft = {
	go = {
		-- "goimports", -- @need-install: go install golang.org/x/tools/cmd/goimports@latest
		"gofmt",
		-- "gofumpt", -- @need-install: go install mvdan.cc/gofumpt@latest
	},
	lua = {
		"stylua", -- @need-install: uv tool install git+https://github.com/johnnymorganz/stylua
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
		-- "isort", -- @need-install: uv tool install --force isort
		-- "black", -- @need-install: uv tool install --force black
	},
	json = {
		"jq", -- @need-install: command -v jq >/dev/null 2>&1 || printf "\033[31m[need-install] missing jq\033[0m\n"
	},
	yaml = {
		"yamlfmt", -- @need-install: go install github.com/google/yamlfmt/cmd/yamlfmt@latest
	},
	toml = {
		"taplo",
	},
	sh = {
		"shfmt", -- @need-install: go install mvdan.cc/sh/v3/cmd/shfmt@latest
	},
	zsh = {
		"shfmt",
	},
	just = { "just" }, -- @need-install: cargo install just
	proto = { "buf" },
	query = { "format-queries" },
	javascript = { "prettier" }, -- @need-install: bun i -g prettier
	typescript = { "prettier" },
	markdown = { "injected" },
	sql = { "sqlfluff" }, -- @need-install: uv tool install --force sqlfluff
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
