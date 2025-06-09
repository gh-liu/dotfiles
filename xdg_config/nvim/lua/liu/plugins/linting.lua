-- https://github.com/mfussenegger/nvim-lint?tab=readme-ov-file#available-linters
local linters_by_ft = {
	go = { "golangcilint" },
	proto = { "buf_lint" },
	bash = { "shellcheck" }, -- sudo apt install shellcheck
	python = { "pylint" }, -- @need-install: uv tool install --force pylint
	sql = { "sqlfluff" }, -- @need-install: uv tool install --force sqlfluff

	-- Use the "*" filetype to run linters on all filetypes.
	-- ['*'] = { 'global linter' },
	-- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
	-- ['_'] = { 'fallback linter' },
	-- ["*"] = { "typos" },
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

	local ft = vim.bo.filetype
	local linters = linters_by_ft[ft] or {}
	linters = vim.list_extend({}, linters)

	-- Add fallback linters.
	if #linters == 0 then
		vim.list_extend(linters, lint.linters_by_ft["_"] or {})
	end
	-- Add fallback linters.
	if #linters == 0 then
		vim.list_extend(linters, lint.linters_by_ft["_"] or {})
	end
	-- Run linters.
	if #linters > 0 then
		lint.try_lint(linters)
	end
end

return {
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
	end,
}
-- }}}
