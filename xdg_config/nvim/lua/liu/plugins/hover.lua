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

-- vim: foldmethod=marker
