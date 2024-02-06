local api = vim.api
local ts = vim.treesitter

local parsers = require("nvim-treesitter.parsers")

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

local ts_foldexpr = "v:lua.vim.treesitter.foldexpr()"
local ts_foldtext = ""

local function set_ts_win_defaults(ev)
	if not vim.b.is_foldable then
		local parser_name = parsers.get_buf_lang()
		if parsers.has_parser(parser_name) then
			local ok, has_folds = pcall(ts.query.get, parser_name, "folds")
			if ok and has_folds then
				vim.b.is_foldable = true
			end
		end
	end

	if vim.b.is_foldable then
		local winid = api.nvim_get_current_win()
		-- Like `:setlocal` if {bufnr} is provided
		local cur_win_opt = vim.wo[winid][0]
		if cur_win_opt.foldmethod == "manual" then
			cur_win_opt.foldmethod = "expr"
			cur_win_opt.foldexpr = ts_foldexpr
		end
		if cur_win_opt.foldtext == "foldtext()" then
			cur_win_opt.foldtext = ts_foldtext
		end
	end
end

api.nvim_create_autocmd({ "BufWinEnter" }, {
	callback = set_ts_win_defaults,
	group = api.nvim_create_augroup("liug/ts_fold", { clear = true }),
	desc = "Set treesitter defaults on win enter",
})
