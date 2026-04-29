-- https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack

--====== git
local aug_fug = vim.api.nvim_create_augroup("liu.fugitive", { clear = true })
vim.pack.add({
	"https://github.com/tpope/vim-fugitive",
	"https://github.com/tpope/vim-rhubarb",
})
vim.keymap.set("n", "g<space>", function()
	local api = vim.api
	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		local buf = api.nvim_win_get_buf(win)
		if vim.b[buf].fugitive_type == "index" then
			api.nvim_buf_delete(buf, { force = true })
			return
		end
	end
	vim.cmd.G({ mods = { keepalt = true } })
end, { silent = true, desc = "Toggle fugitive summary" })
vim.api.nvim_create_autocmd("FileType", {
	group = aug_fug,
	pattern = { "git", "fugitive" },
	callback = function()
		vim.wo[0][0].foldmethod = "syntax"
		if vim.b.fugitive_type == "commit" then
			-- fold all files
			vim.wo[0][0].foldlevel = 0
		end
	end,
})
vim.api.nvim_create_autocmd("FileType", {
	group = aug_fug,
	pattern = "fugitive",
	callback = function()
		vim.cmd([[
			nnoremap <buffer> crt :<C-U>Git reset @~<C-R>=v:count1<CR><CR>
			nnoremap <buffer> crT :<C-U>Git reset --hard @~<C-R>=v:count1<CR><CR>

			nnoremap <buffer> cob :<C-U>Git checkout -b<space>
			"nnoremap <buffer> com :<C-U>Git checkout main<CR>
			"nnoremap <buffer> cbu :<C-U>Git branch -u origin/<C-R>=FugitiveHead()<CR><CR>
			"nnoremap <buffer> cpu :Git push --set-upstream origin <C-R>=FugitiveHead()<CR><CR>

			"cargo install git-absorb
			nnoremap <buffer> gaa :<C-U>Git absorb<space>
			nnoremap <buffer> gar :<C-U>Git absorb --and-rebase<space>
		]])
	end,
})
vim.api.nvim_create_autocmd("User", {
	group = aug_fug,
	pattern = { "FugitiveIndex", "FugitiveObject", "FugitiveStageBlob" },
	callback = function()
		vim.wo[0][0].winhighlight = "StatusLine:StatusLineFugitive"
	end,
})
vim.api.nvim_create_autocmd("SessionLoadPost", {
	group = aug_fug,
	callback = function(ev)
		local buf = ev.buf or api.nvim_get_current_buf()
		if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].fugitive_type == "index" then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end,
})

local aug_ug = vim.api.nvim_create_augroup("liu.ug", { clear = true })
vim.pack.add({ "https://github.com/justinmk/vim-ug" })
vim.api.nvim_create_autocmd("VimEnter", {
	group = aug_ug,
	callback = function(ev)
		vim.cmd([[
			" not gitsigns
			nunmap Un
			nunmap UN
			nunmap <c-n>
			nunmap <c-p>

			"nmap Ubb 1Ub
			"nmap UL 9Ul
		]])
	end,
})

local aug_flog = vim.api.nvim_create_augroup("liu.flog", { clear = true })
vim.pack.add({ "https://github.com/rbong/vim-flog" })
vim.g.flog_enable_dynamic_branch_hl = 0
vim.g.flog_use_internal_lua = 1
vim.g.flog_default_opts = { max_count = 2000 }
vim.g.flog_permanent_default_opts = { date = "format:%Y-%m-%d %H:%M" }
vim.keymap.set("ca", "F", "Flogsplit", {})
vim.api.nvim_create_autocmd("FileType", {
	group = aug_flog,
	pattern = "floggraph",
	callback = function(env)
		local buf = env.buf
		vim.keymap.set("n", "crt", "<Cmd>exec flog#Format('Floggit reset %h')<CR>", { buf = buf })
		vim.keymap.set("n", "crT", "<Cmd>exec flog#Format('Floggit reset --hard %h')<CR>", { buf = buf })
	end,
})

vim.pack.add({
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/neogitorg/neogit",
})

--====== ui
vim.pack.add({ "https://github.com/nvim-mini/mini.icons" })
package.preload["nvim-web-devicons"] = function()
	require("mini.icons").mock_nvim_web_devicons()
	return package.loaded["nvim-web-devicons"]
end

vim.pack.add({ "https://github.com/tpope/vim-flagship" })
vim.o.showtabline = 2
-- default statusline is not empty anymore
-- https://github.com/neovim/neovim/pull/33036
if #vim.o.statusline > 0 then
	-- https://github.com/tpope/vim-flagship/blob/0bb6e26c31446b26900e0d38434f33ba13663cff/autoload/flagship.vim#L606
	vim.o.statusline = "%!flagship#statusline()"
end
-- https://github.com/tpope/vim-flagship/issues/11#issuecomment-149616002
-- a regexp matching any flags you want to opt out of
vim.g.flagship_skip = ""
vim.g.tabprefix = ""
do -- lsp, diagnostic
	vim.diagnostic.status_raw = function(...)
		local ret = vim.api.nvim_eval_statusline(vim.diagnostic.status(...), {})
		return ret.str or ""
	end
	vim.lsp.get_clients_name = function(bufnr)
		return vim.iter(vim.lsp.get_clients({ bufnr = bufnr }))
			:map(function(client)
				local client = client ---@class vim.lsp.Client
				return client.name
			end)
			:join(",")
	end
	vim.cmd([[
		augroup liu.flagship
		  autocmd!
		  " buffer flags (by priority)
		  autocmd User Flags call Hoist("buffer", 9, "%{empty(&buftype) ? flagship#surround(v:lua.vim.diagnostic.status_raw(0)) : ''}")
		  autocmd User Flags call Hoist("buffer", 100, "%{empty(&buftype) ? flagship#surround(v:lua.vim.lsp.get_clients_name(0)) : ''}")
		augroup END
	]])
end

--====== lsp
vim.pack.add({ "https://github.com/neovim/nvim-lspconfig" })

vim.pack.add({ "https://github.com/rachartier/tiny-code-action.nvim" })
vim.lsp.buf.code_action = function(...)
	if not vim.g.did_tiny_code_action_setup then
		vim.g.did_tiny_code_action_setup = true
		require("tiny-code-action").setup({
			picker = {
				"buffer",
				opts = {
					auto_preview = true,
				},
			},
		})
	end
	require("tiny-code-action").code_action(...)
end

--====== treesitter
local aug_treesitter = vim.api.nvim_create_augroup("liu.treesitter", { clear = true })
vim.api.nvim_create_autocmd("PackChanged", {
	group = aug_treesitter,
	callback = function(ev)
		if ev.data.spec.name ~= "nvim-treesitter" or (ev.data.kind ~= "install" and ev.data.kind ~= "update") then
			return
		end
		if ev.data.active then
			-- bun install tree-sitter-cli
			vim.cmd("TSUpdate")
		end
	end,
})
vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter" })
---@class TSCapabilities
---@field highlight boolean
---@field fold boolean
---@field indent boolean
local ts_cache_fts = {} ---@type table<string,TSCapabilities>
local ts_available = nil ---@type table<string,true>?
local ts_installed = nil ---@type table<string,true>?
local ts_installing = {} ---@type table<string,true>
vim.api.nvim_create_autocmd("FileType", {
	group = aug_treesitter,
	callback = function(event)
		local filetype = event.match
		if not ts_cache_fts[filetype] then
			local lang = vim.treesitter.language.get_lang(filetype)
			if not lang then
				return true
			end

			if not ts_available then
				local list = require("nvim-treesitter").get_available()
				ts_available = {}
				for _, l in ipairs(list) do
					ts_available[l] = true
				end
			end
			if not ts_installed then
				local list = require("nvim-treesitter").get_installed()
				ts_installed = {}
				for _, l in ipairs(list) do
					ts_installed[l] = true
				end
			end

			if not ts_available[lang] then
				return
			end

			if not ts_installed[lang] then
				if not ts_installing[lang] then
					require("nvim-treesitter").install(lang, {})
					ts_installing[lang] = true
				end
				return
			end

			ts_cache_fts[filetype] = { highlight = true, fold = false, indent = false }
			if vim.treesitter.query.get(lang, "folds") then
				ts_cache_fts[filetype].fold = true
			end
			if vim.treesitter.query.get(lang, "indents") then
				ts_cache_fts[filetype].indent = true
			end
		end

		if ts_cache_fts[filetype].highlight then
			-- vim.treesitter.start()
			local ok, err = pcall(vim.treesitter.start)
			if not ok then
				-- print(err)
				vim.api.nvim_echo({ { err } }, true, { err = true })
			end
		end
		if ts_cache_fts[filetype].fold then
			vim.wo[0][0].foldmethod = "expr"
			vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
		end
		if ts_cache_fts[filetype].indent then
			vim.bo.indentexpr = "v:lua.require('nvim-treesitter').indentexpr()"
		end
	end,
})

-- vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter-context" })
vim.pack.add({ "https://github.com/gh-liu/nvim-treesitter-context" })
require("treesitter-context").setup({
	multiwindow = true,
	max_lines = 1,
	min_window_height = 0,
	line_numbers = true,
	trim_scope = "outer",
	mode = "topline", ---@type 'cursor' | 'topline'
	separator = nil,
})
vim.api.nvim_set_hl(0, "TreesitterContextBottom", { link = "Underlined", default = true })
