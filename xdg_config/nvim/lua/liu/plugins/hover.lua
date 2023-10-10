local hover = require("hover")

local api = vim.api

-- crates {{{
local ok, crates = pcall(require, "crates")
if ok then
	local fns = {
		popup = { fn = crates.show_popup, priority = 1010 },
		versions = { fn = crates.show_versions_popup, priority = 1009 },
		features = { fn = crates.show_features_popup, priority = 1008 },
		dependencies = { fn = crates.show_dependencies_popup, priority = 1007 },
	}
	for key, val in pairs(fns) do
		hover.register({
			name = string.format("Crates: %s", key),
			enabled = function()
				return vim.fn.expand("%:t") == "Cargo.toml"
			end,
			execute = function(done)
				val.fn()
			end,
			priority = val.priority,
		})
	end
end
-- }}}

-- diagnostic {{{
local diagnostic = vim.diagnostic
local ok, hover = pcall(require, "hover")
if ok then
	hover.register({
		name = "Diagnostic",
		enabled = function()
			local diags = diagnostic.get(0)
			if #diags == 0 then
				return false
			end

			local pos = api.nvim_win_get_cursor(0)
			local lnum = pos[1] - 1
			local col = pos[2]
			local line_length = #api.nvim_buf_get_lines(0, lnum, lnum + 1, true)[1]
			local ds = vim.tbl_filter(function(d)
				return d.lnum == lnum
					and math.min(d.col, line_length - 1) <= col
					and (d.end_col >= col or d.end_lnum > lnum)
			end, diags)

			if vim.tbl_isempty(ds) then
				return false
			end
			return true
		end,
		execute = function(done)
			diagnostic.open_float()
		end,
		priority = 1000,
	})
end
-- }}}

-- -- dapui {{{
-- local ok, dapui = pcall(require, "dapui")
-- if ok then
-- 	hover.register({
-- 		name = "DAP",
-- 		enabled = function()
-- 			return vim.g.debuging == 1
-- 		end,
-- 		execute = function(done)
-- 			dapui.eval(nil, {})
-- 		end,
-- 		priority = 1001,
-- 	})
-- end
-- -- }}}

-- vim: foldmethod=marker
