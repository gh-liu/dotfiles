return {
	{
		"nvim-treesitter/nvim-treesitter",
		init = function()
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(event)
					local filetype = event.match
					local lang = vim.treesitter.language.get_lang(filetype)
					if not lang then
						return
					end

					if not vim.tbl_contains(require("nvim-treesitter").get_available(), lang) then
						return
					end

					vim.treesitter.start()

					if vim.treesitter.query.get(lang, "folds") then
						vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
					end
					if vim.treesitter.query.get(lang, "indents") then
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
}
