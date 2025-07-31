---@class TSCapabilities
---@field highlight boolean
---@field fold boolean
---@field indent boolean

local cache_fts = {} ---@type table<string,TSCapabilities>

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
							return
						end

						if not vim.tbl_contains(require("nvim-treesitter").get_installed(), lang) then
							require("nvim-treesitter").install(lang, {})
							return
						end

						cache_fts[filetype] = { highlight = true }
						if vim.treesitter.query.get(lang, "folds") then
							cache_fts[filetype].fold = true
						end
						if vim.treesitter.query.get(lang, "indents") then
							cache_fts[filetype].indent = true
						end
					end

					if cache_fts[filetype].highlight then
						vim.treesitter.start()
					end
					if cache_fts[filetype].fold then
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
			vim.api.nvim_set_hl(0, "TreesitterContextLineNumber", { link = "Title" })
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
}
