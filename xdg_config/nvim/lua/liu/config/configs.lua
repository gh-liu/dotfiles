--- can be override by snacks.bufdelete or require("mini.bufremove").delete
---@param buf number
_G.bufdelete = function(buf)
	vim.api.nvim_buf_call(buf, function()
		vim.cmd([[buf# | bd#]])

		-- vim.cmd([[buf#]])
		-- vim.api.nvim_buf_delete(buf, { force = true })
	end)
end
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		local config = require("liu.user_config")
		local diag_icons = config.icons.diagnostics
		-- https://neovim.io/doc/user/diagnostic.html
		local diagnostic = vim.diagnostic
		local min_serverity = diagnostic.severity.INFO
		diagnostic.config({
			underline = { severity = { min = min_serverity } },
			signs = false,
			-- signs = {
			-- 	severity = { min = min_serverity },
			-- 	text = diag_icons,
			-- },
			float = {
				source = true,
				border = config.borders,
				show_header = false,
				prefix = function(diag)
					local level = vim.diagnostic.severity[diag.severity]
					local prefix = string.format(" %s ", diag_icons[level])
					return prefix, "Diagnostic" .. level:gsub("^%l", string.upper)
				end,
			},
			severity_sort = true,
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
			update_in_insert = false,
		})
	end,
})
