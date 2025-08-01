vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		local config = require("liu.user_config")
		local diag_icons = config.icons.diagnostics
		-- https://neovim.io/doc/user/diagnostic.html
		local diagnostic = vim.diagnostic
		diagnostic.config({
			severity_sort = true,
			update_in_insert = false,
			jump = {},
			float = {
				source = true,
				border = config.borders,
				show_header = true,
				prefix = function(diag)
					local level = vim.diagnostic.severity[diag.severity]
					local prefix = string.format(" %s ", diag_icons[level])
					return prefix, "Diagnostic" .. level:gsub("^%l", string.upper)
				end,
			},
			signs = false,
			underline = true,
			virtual_lines = false,
			virtual_text = {
				prefix = "",
				spacing = 2,
				format = function(diagnostic)
					-- Use shorter, nicer names for some sources:
					local special_sources = {
						["Lua Diagnostics."] = "lua",
						["Lua Syntax Check."] = "lua",
					}

					-- use icon replace prefix
					local message = diag_icons[vim.diagnostic.severity[diagnostic.severity]]
					if diagnostic.source then
						message =
							string.format("%s %s", message, special_sources[diagnostic.source] or diagnostic.source)
					end
					if diagnostic.code then
						message = string.format("%s [%s]", message, diagnostic.code)
					end

					return message .. " "
				end,
			},
		})
	end,
})
