return {
	{
		"nvim-treesitter/nvim-treesitter",
		event = "VeryLazy",
		build = ":TSUpdate",
		opts = {
			ensure_installed = "all",
			ignore_install = {},
			sync_install = false,
			auto_install = true,
			highlight = {
				enable = true,
				disable = function(lang, buf)
					if vim.tbl_contains({ "tmux" }, lang) then
						return true
					end

					local max_filesize = 256 * 1024 -- 256 KB
					---@diagnostic disable-next-line: undefined-field
					local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
					if ok and stats and stats.size > max_filesize then
						return true
					end
				end,
			},
			indent = { enable = true },
			incremental_selection = { enable = false },
		},
		config = function(self, opts)
			require("nvim-treesitter.configs").setup(opts)
		end,
	},
}
