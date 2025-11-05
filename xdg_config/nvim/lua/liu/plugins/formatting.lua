-- :help conform-formatters
local formatters_by_ft = {
	go = {
		-- "goimports", -- @need-install: go install golang.org/x/tools/cmd/goimports@latest
		"gofmt",
		-- "gofumpt",
	},
	lua = {
		"stylua", -- @need-install: cargo install stylua
	},
	rust = {
		"rustfmt",
	},
	-- zig = {
	-- 	"zigfmt",
	-- },
	-- python = {
	-- 	-- pip3 install isort
	-- 	-- @need-install: uv tool install --force isort
	-- 	"isort",
	-- 	-- pip install black
	-- 	-- @need-install: uv tool install --force black
	-- 	"black",
	-- },
	json = {
		"jq",
	},
	yaml = {
		"yamlfmt", -- @need-install: go install github.com/google/yamlfmt/cmd/yamlfmt@latest
	},
	toml = {
		"taplo", -- @need-install: cargo install taplo-cli
	},
	sh = {
		"shfmt", -- @need-install: go install mvdan.cc/sh/v3/cmd/shfmt@latest
	},
	zsh = {
		"shfmt",
	},
	just = { "just" },
	proto = { "buf" },
	query = { "format-queries" },
	javascript = { "prettier" }, -- @need-install: bun i -g prettier
	typescript = { "prettier" },
	markdown = { "injected" },
	sql = { "sqlfluff" },
	terraform = { "terraform_fmt" },
}

return {
	"stevearc/conform.nvim",
	lazy = true,
	init = function(self)
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

		if vim.g.DisableAutoFormat == nil then
			vim.g.DisableAutoFormat = 1
		end
	end,
	keys = {
		{
			"yoF",
			function()
				if vim.g.DisableAutoFormat == 0 then
					vim.g.DisableAutoFormat = 1
					vim.notify("Disabled autoformat", vim.log.levels.WARN)
				else
					vim.g.DisableAutoFormat = 0
					vim.notify("Enabled autoformat", vim.log.levels.WARN)
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
	},
	config = function(self, opts)
		opts.format_on_save = function(bufnr)
			if vim.g.DisableAutoFormat == 1 or vim.b[bufnr].DisableAutoFormat == 1 then
				return
			end
			return {
				timeout_ms = 500,
				lsp_format = "fallback",
			}
		end
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
