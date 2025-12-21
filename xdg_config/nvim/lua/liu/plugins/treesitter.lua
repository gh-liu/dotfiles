---@class TSCapabilities
---@field highlight boolean
---@field fold boolean
---@field indent boolean

local cache_fts = {} ---@type table<string,TSCapabilities>
local available = nil
local installed = nil
local installing = {}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		init = function()
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(event)
					local filetype = event.match
					if not cache_fts[filetype] then
						local lang = vim.treesitter.language.get_lang(filetype)
						if not lang then
							return true
						end

						if not available then
							available = require("nvim-treesitter").get_available()
						end
						if not installed then
							installed = require("nvim-treesitter").get_installed()
						end

						if not vim.tbl_contains(available, lang) then
							return true
						end

						if not vim.tbl_contains(installed, lang) then
							if not installing[lang] then
								require("nvim-treesitter").install(lang, {})
							else
								installing[lang] = true
							end
							return true
						end

						cache_fts[filetype] = { highlight = true, fold = false, indent = false }
						if vim.treesitter.query.get(lang, "folds") then
							cache_fts[filetype].fold = true
						end
						if vim.treesitter.query.get(lang, "indents") then
							cache_fts[filetype].indent = true
						end
					end

					if cache_fts[filetype].highlight then
						-- vim.treesitter.start()
						local ok, err = pcall(vim.treesitter.start)
						if not ok then
							-- print(err)
							vim.api.nvim_echo({ { err } }, true, { err = true })
						end
					end
					if cache_fts[filetype].fold then
						vim.wo[0][0].foldmethod = "expr"
						vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
					end
					if cache_fts[filetype].indent then
						vim.bo.indentexpr = "v:lua.require('nvim-treesitter').indentexpr()"
					end
				end,
				group = vim.api.nvim_create_augroup("liu/ts_setup", {}),
			})
		end,
		branch = "main",
		event = "VeryLazy",
		build = ":TSUpdate",
		opts = {},
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		event = "VeryLazy",
		init = function()
			vim.api.nvim_create_autocmd("VimEnter", {
				callback = function()
					for _, query in ipairs(vim.api.nvim_get_runtime_file("after/queries/*/context.scm", true)) do
						local lang = string.match(query, "after/queries/(.*)/context.scm")
						vim.treesitter.query.set(lang, "context", vim.iter(vim.fn.readfile(query)):join("\n"))
					end
				end,
			})

			-- vim.api.nvim_set_hl(0, "TreesitterContextLineNumber", { link = "Tag" })
			vim.api.nvim_set_hl(0, "TreesitterContextBottom", { link = "Underlined" })
		end,
		opts = {
			multiwindow = true,
			max_lines = 1,
			min_window_height = 0,
			line_numbers = true,
			trim_scope = "outer",
			mode = "topline", ---@type 'cursor' | 'topline'
			separator = nil,
		},
	},
	{
		"HiPhish/rainbow-delimiters.nvim",
		init = function()
			-- vim.api.nvim_set_hl(0, "RainbowDelimiterRed", { link = "DiagnosticError" })
			-- vim.api.nvim_set_hl(0, "RainbowDelimiterYellow", { link = "DiagnosticWarn" })
			-- vim.api.nvim_set_hl(0, "RainbowDelimiterBlue", { link = "DiagnosticInfo" })
			-- vim.api.nvim_set_hl(0, "RainbowDelimiterOrange", { link = "DiagnosticHint" })
			-- vim.api.nvim_set_hl(0, "RainbowDelimiterGreen", { link = "DiagnosticOk" })
			-- vim.api.nvim_set_hl(0, "RainbowDelimiterViolet" ,{link = ""})
			-- vim.api.nvim_set_hl(0, "RainbowDelimiterCyan"   ,{link = ""})

			vim.g.rainbow_delimiters = {
				strategy = {
					[""] = "rainbow-delimiters.strategy.global",
					-- [""] = "rainbow-delimiters.strategy.local",
				},
				priority = {
					[""] = vim.hl.priorities.user + 1,
				},
				-- query = {},
				highlight = {
					"@punctuation.bracket",
					"DiagnosticError",
					"DiagnosticWarn",
					"DiagnosticInfo",
					"DiagnosticHint",
					"DiagnosticOk",
				},
			}
		end,
	},
}
