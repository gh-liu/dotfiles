-- https://github.com/mfussenegger/nvim-lint?tab=readme-ov-file#available-linters
local linters_by_ft = {
	go = { "golangcilint" }, -- @need-install: go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
	proto = { "buf_lint" },
	bash = { "shellcheck" }, -- @need-install: command -v shellcheck >/dev/null 2>&1 || printf "\033[31m[need-install] missing shellcheck\033[0m\n"
	-- python = { "pylint" }, -- @need-install: uv tool install --force pylint
	-- sql = { "sqlfluff" }, -- @need-install: uv tool install --force sqlfluff

	-- Use the "*" filetype to run linters on all filetypes.
	-- ['*'] = { 'global linter' },
	-- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
	-- ['_'] = { 'fallback linter' },
	-- ["*"] = { "typos" },
}

---@class LinterCondCtx
---@field filename string
---@field dirname string

---@type table<string,table>
local linters_opt = {
	golangcilint = {
		---@param ctx LinterCondCtx
		---@return boolean
		condition = function(ctx)
			-- Only lint files within current working directory
			if not vim.startswith(ctx.dirname, ctx.cwd) then
				return false
			end
			-- Only lint if golangci-lint config file exists
			return #vim.fs.find(
				{ ".golangci.yml", ".golangci.yaml", ".golangci.toml", ".golangci.json" },
				{ path = ctx.dirname, upward = true }
			) > 0
		end,
	},
}

local M = {}

function M.debounce(ms, fn)
	local timer = vim.uv.new_timer()
	return function(...)
		local argv = { ... }
		timer:start(ms, 0, function()
			timer:stop()
			vim.schedule_wrap(fn)(unpack(argv))
		end)
	end
end
function M.lint()
	local lint = require("lint")

	local linters = vim.b.linters
	if not linters then
		local ft = vim.bo.filetype
		linters = linters_by_ft[ft] or {}
		linters = vim.list_extend({}, linters)

		-- Add fallback linters.
		if #linters == 0 then
			vim.list_extend(linters, lint.linters_by_ft["_"] or {})
		end
		-- Add global linter
		if lint.linters_by_ft["*"] then
			vim.list_extend(linters, lint.linters_by_ft["*"])
		end
		vim.b.linters = linters
	end
	if #linters > 0 then
		-- Filter out linters that don't exist or don't match the condition.
		local ctx = { filename = vim.api.nvim_buf_get_name(0) }
		ctx.dirname = vim.fn.fnamemodify(ctx.filename, ":h")
		ctx.cwd = vim.fn.getcwd()
		linters = vim.iter(linters)
			:filter(function(name)
				local linter_opt = linters_opt[name]
				if linter_opt and type(linter_opt) == "table" and linter_opt.condition then
					return linter_opt.condition(ctx)
				end
				return true
			end)
			:totable()
		vim.b.linters = linters
	end
	-- Run linters.
	if #linters > 0 then
		lint.try_lint(linters)
	end
end

return {
	-- Async linter running external tools and displaying results via vim.diagnostics
	"mfussenegger/nvim-lint",
	lazy = true,
	init = function(self)
		vim.api.nvim_create_autocmd({
			"BufWritePost",
			"BufReadPost",
			"InsertLeave",
			-- "TextChanged",
		}, {
			group = vim.api.nvim_create_augroup("liu/nvim-lint", { clear = true }),
			callback = M.debounce(100, M.lint),
		})
	end,
	opts = {
		linters_by_ft = linters_by_ft,
	},
	config = function(self, opts)
		require("lint").linters_by_ft = opts.linters_by_ft

		local ori_sqlfluff = require("lint").linters.sqlfluff
		require("lint").linters.sqlfluff = function()
			local linter = ori_sqlfluff
			local dialect = vim.b.sql_dialect or vim.b.sql_type_override or vim.g.sql_type_default
			if dialect then
				linter.args = {
					"lint",
					"--format=json",
					"--dialect=" .. dialect,
				}
			end
			return linter
		end
	end,
}
-- }}}
