local api = vim.api

---@diagnostic disable-next-line: missing-fields
require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"c",
		"lua",
		"vim",
		"vimdoc",
		"comment",
		"go",
		"gosum",
		"gomod",
		"gowork",
		"rust",
		"bash",
		"regex",
		"diff",
		"gitignore",
		"gitcommit",
		"git_rebase",
	},
	sync_install = false,
	auto_install = true,
	highlight = {
		enable = true,
		-- Disable slow treesitter highlight for large files
		disable = function(lang, buf)
			local max_filesize = 64 * 1024 -- 64 KB
			local ok, stats = pcall(vim.loop.fs_stat, api.nvim_buf_get_name(buf))
			if ok and stats and stats.size > max_filesize then
				return true
			end
		end,
	},
	indent = { enable = true },
	incremental_selection = { enable = false },
})

-- Navigation {{{1
-- copied from nvim-treesitter-refactor/navigation.lua
local ts_utils = require("nvim-treesitter.ts_utils")
local locals = require("nvim-treesitter.locals")

local M = {}

function M.goto_next_usage(bufnr)
	return M.goto_adjacent_usage(bufnr, 1)
end
function M.goto_previous_usage(bufnr)
	return M.goto_adjacent_usage(bufnr, -1)
end

local function index_of(tbl, obj)
	for i, o in ipairs(tbl) do
		if o == obj then
			return i
		end
	end
end

function M.goto_adjacent_usage(bufnr, delta)
	local bufnr = bufnr or api.nvim_get_current_buf()
	local node_at_point = ts_utils.get_node_at_cursor()
	if not node_at_point then
		return
	end

	local def_node, scope = locals.find_definition(node_at_point, bufnr)
	local usages = locals.find_usages(def_node, scope, bufnr)

	local index = index_of(usages, node_at_point)
	if not index then
		return
	end

	local target_index = (index + delta + #usages - 1) % #usages + 1
	ts_utils.goto_node(usages[target_index])
end

-- if lsp server supports document highlight, which will replce below two maps
vim.keymap.set("n", "]v", M.goto_next_usage)
vim.keymap.set("n", "[v", M.goto_previous_usage)
-- }}}

-- vim: foldmethod=marker
