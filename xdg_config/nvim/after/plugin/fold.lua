if false then
	return
end

local api = vim.api
local ts = vim.treesitter

local ts_foldexpr = "v:lua.vim.treesitter.foldexpr()"
local ts_foldtext = ""

local is_foldable = function(buf)
	buf = buf or api.nvim_get_current_buf()
	local lang = ts.language.get_lang(api.nvim_get_option_value("filetype", { buf = buf }))
	local ok, has_folds = pcall(ts.query.get, lang, "folds")
	if ok and has_folds then
		return true
	end
	return false
end

local set_treesitter_fold = function(win)
	-- Like `:setlocal` if {bufnr} is provided
	local cur_win_opt = vim.wo[win][0]
	-- if current `foldmethod` is `manual`, then changed to `expr` and set `foldexpr`
	if cur_win_opt.foldmethod == "manual" then
		cur_win_opt.foldmethod = "expr"
		cur_win_opt.foldexpr = ts_foldexpr
	end

	-- if current `foldtext` is `foldtext()`, then change the foldtext
	if cur_win_opt.foldtext == "foldtext()" then
		cur_win_opt.foldtext = ts_foldtext
	end
end

local function set_ts_win_defaults(ev)
	if ev.match == "" then
		return
	end
	local buf = ev.buf
	if not vim.b.is_foldable then
		vim.b.is_foldable = is_foldable(buf)
	end

	if vim.b.is_foldable then
		local winid = api.nvim_get_current_win()
		set_treesitter_fold(winid)
	end
end

api.nvim_create_autocmd({
	"BufWinEnter",
}, {
	callback = set_ts_win_defaults,
	group = liu_augroup("ts_fold"),
	desc = "set treesitter fold",
})
