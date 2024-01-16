local api = vim.api

---@diagnostic disable-next-line: missing-fields
require("nvim-treesitter.configs").setup({
	ensure_installed = "all",
	ignore_install = {},
	sync_install = false,
	auto_install = true,
	highlight = {
		enable = true,
		disable = function(_, buf)
			-- Don't disable for read-only buffers.
			if not vim.bo[buf].modifiable then
				return false
			end

			local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
			-- Disable for files larger than 256 KB.
			return ok and stats and stats.size > (256 * 1024)
		end,
	},
	indent = { enable = true },
	incremental_selection = { enable = false },
})

local nav = require("liu.treesitter.navigation")
nav.map_object_pair_move("f", "@function.outer", true)
nav.map_object_pair_move("F", "@function.outer", false)
local usage = nav.usage
-- if lsp server supports document highlight, which will replce below map
vim.keymap.set("n", "]v", usage.goto_next)
vim.keymap.set("n", "[v", usage.goto_prev)

local edit = require("liu.treesitter.edit")
-- if lsp server supports document rename, which will replce below map
vim.keymap.set("n", "<leader>rn", edit.smart_rename)
