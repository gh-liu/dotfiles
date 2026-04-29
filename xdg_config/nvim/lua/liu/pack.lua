-- https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack

vim.api.nvim_create_user_command("Pack", function()
	vim.ui.select(vim.pack.get(), {
		format_item = function(plugin)
			return plugin.spec.name
		end,
	}, function(plugin)
		vim.print(plugin)
	end)
end, { nargs = 0 })

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

--====== picker
vim.pack.add({ "https://github.com/folke/snacks.nvim" })
require("snacks").setup({
	-- :h snacks.nvim-picker-config
	picker = {
		enabled = true,
		win = {
			input = { keys = input_keys, wo = {} },
			list = { wo = {} },
			preview = { wo = {} },
		},
	},
})
vim.ui.select = function(...)
	require("snacks.picker.select").select(...)
end
local picker_map = function(op, cmd, opts)
	opts = opts or {}
	vim.keymap.set("n", "<leader>s" .. op, function()
		require("snacks").picker(cmd, opts)
		-- require("snacks.picker")[cmd](opts)
	end)
end
picker_map("b", "buffers")
picker_map("d", "diagnostics_buffer")
picker_map("f", "files")
picker_map("j", "jumps")
picker_map("g", "live_grep")
picker_map("h", "help")
picker_map("m", "marks")
picker_map("s", "lsp_symbols")
picker_map("w", "grep_word")
picker_map("o", "recent", { filter = { cwd = true } })

--====== cmp
local cmp_float_opts = {
	border = vim.o.winborder,
	winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
}
vim.pack.add({ "https://github.com/rafamadriz/friendly-snippets" })
local aug_blink_cmp = vim.api.nvim_create_augroup("liu.blink.cmp", { clear = true })
vim.pack.add(
	{ {
		src = "https://github.com/saghen/blink.cmp",
		version = vim.version.range("1.*"),
	} },
	{ load = function() end }
)
vim.api.nvim_create_autocmd("InsertEnter", {
	group = aug_blink_cmp,
	callback = function()
		vim.cmd.packadd("blink.cmp")
		require("blink.cmp").setup({
			enabled = function()
				return not (vim.bo.buftype == "prompt" or vim.b.completion)
			end,
			keymap = {
				-- preset = "default",
				--
				-- Available commands: https://cmp.saghen.dev/configuration/keymap.html#commands
				--	show, hide, cancel, accept,
				-- 	select_and_accept, select_prev, select_next,
				-- 	show_documentation, hide_documentation,
				-- 	scroll_documentation_up, scroll_documentation_down,
				-- 	snippet_forward, snippet_backward,
				--
				-- ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
				["<C-e>"] = { "hide", "fallback" },
				["<C-y>"] = { "accept", "fallback" },
				["<CR>"] = { "select_and_accept", "fallback" },

				["<Tab>"] = { "select_next", "fallback" },
				["<S-Tab>"] = { "select_prev", "fallback" },

				["<C-p>"] = { "select_prev", "fallback" },
				["<C-n>"] = { "select_next", "fallback" },

				["<C-l>"] = { "snippet_forward", "fallback" },
				["<C-h>"] = { "snippet_backward", "fallback" },

				["<C-b>"] = { "scroll_documentation_up", "fallback" },
				["<C-f>"] = { "scroll_documentation_down", "fallback" },
			},
			appearance = {},
			completion = {
				-- trigger = {},
				-- list = {},
				accept = {
					-- Experimental auto-brackets support
					auto_brackets = {
						enabled = true,
					},
				},
				menu = vim.tbl_extend("force", cmp_float_opts, {
					draw = {
						-- Use treesitter to highlight the label text
						-- for the given list of sources
						treesitter = { "lsp" },
						columns = {
							{ "label", "label_description", gap = 1 },
							{ "kind_icon", "kind", gap = 1 },
							{ "source_name", gap = 1 },
						},
						components = {
							source_name = {
								text = function(ctx)
									return string.format("[%s]", string.sub(ctx.item.source_name, 0, 3))
								end,
								highlight = "PreProc",
							},
							kind_icon = {
								text = function(ctx)
									local kind_icon, _, _ = require("mini.icons").get("lsp", ctx.kind)
									return kind_icon
								end,
								highlight = function(ctx)
									local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
									return hl
								end,
							},
							kind = {
								highlight = function(ctx)
									local _, hl, _ = require("mini.icons").get("lsp", ctx.kind)
									return hl
								end,
							},
						},
					},
				}),
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
					window = cmp_float_opts,
				},
				-- ghost_text = {},
			},
			signature = { -- NOTE: !experimental
				enabled = true,
				window = cmp_float_opts,
			},
			sources = {
				default = function(ctx)
					local buf_sourcess = vim.b.blink_cmp_sources
					if buf_sourcess then
						if type(buf_sourcess) == "table" then
							return buf_sourcess
						end
						if type(buf_sourcess) == "string" then
							return vim.split(buf_sourcess, ",")
						end
					end

					-- local node = vim.treesitter.get_node()
					-- if node and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type()) then
					-- 	return { "buffer" }
					-- end

					local default = { "lsp", "path", "snippets", "buffer" }
					-- local buf_sources_inherit = vim.b.blink_cmp_sources_inherit
					-- if buf_provider_inherit then
					-- 	local providers = {}
					-- 	if type(buf_provider_inherit) == "table" then
					-- 		providers = buf_provider_inherit
					-- 	end
					-- 	if type(buf_provider_inherit) == "string" then
					-- 		providers = vim.split(buf_provider_inherit, ",")
					-- 	end
					-- 	for _, p in ipairs(providers) do
					-- 		table.insert(default, p)
					-- 	end
					-- end
					return default
				end,
				-- per_filetype = { lua = { inherit_defaults = true, "lazydev" } },
				providers = {
					path = {
						opts = {
							-- path completion from cwd instead of current buffer’s directory
							get_cwd = function(_)
								return vim.fn.getcwd()
							end,
						},
					},
				},
			},
			-- https://cmp.saghen.dev/configuration/reference#cmdline
			cmdline = {
				enabled = false,
				sources = { "cmdline", "buffer" },
			},
			-- https://cmp.saghen.dev/configuration/reference#terminal
			term = {
				enabled = false,
				sources = { "buffer" },
			},
			-- https://cmp.saghen.dev/recipes.html#fuzzy-sorting-filtering
			fuzzy = {
				implementation = "prefer_rust_with_warning",
				-- sort = {},
			},
		})
	end,
	once = true,
})

local aug_mini_pairs = vim.api.nvim_create_augroup("liu.mini.pairs", { clear = true })
vim.pack.add({ "https://github.com/nvim-mini/mini.pairs" }, { load = function() end })
vim.api.nvim_create_autocmd("InsertEnter", {
	group = aug_mini_pairs,
	callback = function()
		vim.cmd.packadd("mini.pairs")
		require("mini.pairs").setup({
			modes = { insert = true, command = true, terminal = false },
		})
	end,
	once = true,
})

--====== lint
local aug_lint = vim.api.nvim_create_augroup("liu.lint", { clear = true })
vim.pack.add({ "https://github.com/mfussenegger/nvim-lint" })
-- https://github.com/mfussenegger/nvim-lint?tab=readme-ov-file#available-linters
local linters_by_ft = {
	go = { "golangcilint" },
	proto = { "buf_lint" },
	bash = { "shellcheck" },
	-- python = { "pylint" },
	-- sql = { "sqlfluff" },
	javascript = { "oxlint" },
	typescript = { "oxlint" },

	-- Use the "*" filetype to run linters on all filetypes.
	-- ['*'] = { 'global linter' },
	-- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
	-- ['_'] = { 'fallback linter' },
	-- ["*"] = { "typos" },
}
require("lint").linters_by_ft = linters_by_ft
vim.api.nvim_create_autocmd({
	"BufWritePost",
	"BufReadPost",
	"InsertLeave",
	-- "TextChanged",
}, {
	group = aug_lint,
	callback = function()
		require("lint").try_lint()
	end,
})

--====== format
vim.pack.add({ "https://github.com/stevearc/conform.nvim" })
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
local formatters_by_ft = {
	go = { "gofmt" },
	lua = { "stylua" },
	rust = { "rustfmt" },
	zig = { "zigfmt" },
	python = { "ruff_format", "ruff_organize_imports" },
	javascript = { "oxfmt" },
	typescript = { "oxfmt" },
	markdown = { "injected" },
	json = { "jq" },
	yaml = { "yamlfmt" },
	toml = { "taplo" },
	proto = { "buf" },
	sh = { "shfmt" },
	zsh = { "shfmt" },
	just = { "just" },
	query = { "format-queries" },
}
require("conform").setup({
	-- :help conform-formatters
	formatters_by_ft = formatters_by_ft,
	default_format_opts = { lsp_format = "fallback" },
	format_on_save = function(bufnr)
		return {
			lsp_format = "fallback",
			timeout_ms = 500,
		}
	end,
})

--====== textobj, operator
-- vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" })
vim.pack.add({ "https://github.com/gh-liu/nvim-treesitter-textobjects" })

vim.pack.add({ "https://github.com/nvim-mini/mini.ai" })
local mini_ai_gen = require("mini.ai").gen_spec
local mini_ai_ts_gen = mini_ai_gen.treesitter
require("mini.ai").setup({
	silent = true,
	search_method = "cover",
	n_lines = 300,
	custom_textobjects = {
		-- Code blocks (if/for/while/etc.)
		o = mini_ai_ts_gen({
			a = { "@block.outer", "@conditional.outer", "@loop.outer" },
			i = { "@block.inner", "@conditional.inner", "@loop.inner" },
		}),
		-- Function
		f = mini_ai_ts_gen({ a = "@function.outer", i = "@function.inner" }, {}),
		-- Class
		c = mini_ai_ts_gen({ a = "@class.outer", i = "@class.inner" }, {}),
		-- NOTE: Use built-in `a` for argument/parameter instead of custom `P`
		-- Assignment: = for whole, l for lhs, r for rhs
		["="] = mini_ai_ts_gen({ a = "@assignment.outer", i = "@assignment.inner" }, {}),
		l = mini_ai_ts_gen({ a = "@assignment.lhs", i = "@assignment.lhs" }, {}), -- lhs (left-hand side)
		r = mini_ai_ts_gen({ a = "@assignment.rhs", i = "@assignment.rhs" }, {}), -- rhs (right-hand side)
		-- Function call (usage)
		u = mini_ai_gen.function_call(),
	},
	mappings = {
		-- Move cursor to corresponding edge of `a` textobject
		-- goto_left = "g[",
		-- goto_right = "g]",
		goto_left = "",
		goto_right = "",
	},
})

vim.pack.add({ "https://github.com/nvim-mini/mini.surround" })
local mini_surround_ts_input = require("mini.surround").gen_spec.input.treesitter
require("mini.surround").setup({
	mappings = {
		add = "ys", -- Add surrounding in Normal and Visual modes
		delete = "ds", -- Delete surrounding
		replace = "cs", -- Replace surrounding

		find = "", -- Find surrounding (to the right) - surround next
		find_left = "", -- Find surrounding (to the left) - surround prev
		highlight = "", -- Highlight surrounding - surround highlight
		update_n_lines = "", -- Update `n_lines`

		suffix_last = "l", -- Suffix to search with "prev" method
		suffix_next = "n", -- Suffix to search with "next" method
	},
	custom_textobjects = {
		f = mini_surround_ts_input({ outer = "@call.outer", inner = "@call.inner" }),
	},
	n_lines = 300,
	search_method = "cover",
})
vim.keymap.set("n", "yS", "ys$", { remap = true })
vim.keymap.set("n", "yss", "ys_", { remap = true })

vim.pack.add({ "https://github.com/nvim-mini/mini.operators" })
require("mini.operators").setup({
	replace = {
		prefix = "dr",
		reindent_linewise = true,
	},
	exchange = {
		prefix = "cx",
		reindent_linewise = true,
	},
	evaluate = { prefix = "g=" },
	multiply = { prefix = "" },
	sort = { prefix = "" },
})

vim.pack.add({ "https://github.com/nvim-mini/mini.move" })
require("mini.move").setup({})

vim.pack.add({ "https://github.com/nvim-mini/mini.align" })
require("mini.align").setup({
	mappings = {
		start = "gl",
		start_with_preview = "gL",
	},
})

vim.pack.add({ "https://github.com/monaqa/dial.nvim" })
vim.keymap.set({ "n", "v" }, "<C-a>", "<Plug>(dial-increment)", {})
vim.keymap.set({ "n", "v" }, "<C-x>", "<Plug>(dial-decrement)", {})
vim.keymap.set({ "n", "v" }, "g<C-a>", "<Plug>(dial-g-increment)", {})
vim.keymap.set({ "n", "v" }, "g<C-x>", "<Plug>(dial-g-decrement)", {})

vim.pack.add({ "https://github.com/Wansmer/treesj" })
require("treesj").setup({ use_default_keymaps = false, max_join_length = 300 })
vim.keymap.set("n", "gJ", "<CMD>TSJJoin<CR>", {})
vim.keymap.set("n", "gS", "<CMD>TSJSplit<CR>", {})

vim.pack.add({ "https://github.com/tpope/vim-repeat" })
vim.pack.add({ "https://github.com/tpope/vim-abolish" })
vim.g.abolish_save_file = vim.fn.stdpath("config") .. "/after/plugin/abolish.vim"

--====== editor
vim.pack.add({ "https://github.com/justinmk/vim-dirvish" })
vim.g.loaded_netrwPlugin = 1

local aug_mini_files = vim.api.nvim_create_augroup("liu.mini.files", { clear = true })
vim.pack.add({ "https://github.com/nvim-mini/mini.files" })
vim.api.nvim_create_autocmd("User", {
	group = aug_mini_files,
	pattern = "MiniFilesExplorerOpen",
	callback = function()
		local MiniFiles = require("mini.files")
		MiniFiles.set_bookmark("~", "~", { desc = "Home directory" })
		MiniFiles.set_bookmark("C", vim.fn.stdpath("config"), { desc = "nvim Config directory" })
		MiniFiles.set_bookmark("w", vim.fn.getcwd, { desc = "Working directory" })
		MiniFiles.set_bookmark("r", function()
			return vim.fs.root(0, { ".git" }) or vim.fn.getcwd()
		end, { desc = "Root directory" })
	end,
})
vim.keymap.set("n", "<leader>E", function()
	local MiniFiles = require("mini.files")
	if not MiniFiles.close() then
		local path = vim.fn.getcwd()
		MiniFiles.open(path, false)
	end
end)
vim.keymap.set("n", "<leader>e", function()
	local MiniFiles = require("mini.files")
	if not MiniFiles.close() then
		local bufname = vim.api.nvim_buf_get_name(0)
		local is_dir = vim.fn.isdirectory(bufname) == 1
		local dirs = {}
		if is_dir then
			table.insert(dirs, bufname)
		else
			local file_not_valid = bufname == "" or vim.fn.filereadable(bufname) == 0
			if file_not_valid then
				bufname = vim.fs.normalize(vim.fn.getcwd(), {})
				table.insert(dirs, bufname)
			end
		end
		for dir in vim.fs.parents(bufname) do
			table.insert(dirs, dir)
		end

		local count = vim.v.count1
		local path = dirs[count]
		if count == 1 and vim.fn.isdirectory(bufname) == 0 then
			-- If it is a path to file, its parent directory is used as anchor
			-- while explorer will focus on the supplied file.
			MiniFiles.open(bufname, false)
		else
			MiniFiles.open(path, false)
		end
	end
end)

local aug_mini_bufremove = vim.api.nvim_create_augroup("liu.mini.bufremove", { clear = true })
vim.pack.add({ "https://github.com/nvim-mini/mini.bufremove" })
require("mini.bufremove").setup({})
vim.api.nvim_create_autocmd("User", {
	group = aug_mini_bufremove,
	pattern = "MiniFilesActionDelete",
	callback = function(args)
		local fname = args.data.from
		local buf = vim.fn.bufnr(fname)
		if vim.api.nvim_buf_is_valid(buf) then
			require("mini.bufremove").delete(buf, false)
		end
	end,
})

vim.pack.add({ "https://github.com/nvim-mini/mini.keymap" })
local map_combo = require("mini.keymap").map_combo
map_combo({ "i", "x", "s" }, "jk", "<BS><BS><Esc>")
local map_multistep = require("mini.keymap").map_multistep
map_multistep({ "i" }, "<Tab>", {
	"vimsnippet_next",
	"pmenu_next",
	-- "blink_next",
})
map_multistep({ "i" }, "<S-Tab>", {
	"vimsnippet_prev",
	"pmenu_prev",
	-- "blink_prev",
})
map_multistep({ "i", "s" }, "<C-l>", { "vimsnippet_next" })
map_multistep({ "i", "s" }, "<C-h>", { "vimsnippet_prev" })

vim.pack.add({ "https://github.com/nvim-mini/mini.diff" })
require("mini.diff").setup({
	view = {
		-- Visualization style. Possible values are 'sign' and 'number'.
		style = "sign",
		-- Signs used for hunks with 'sign' view
		signs = { add = "▒", change = "▒", delete = "▒" },
		-- Priority of used visualization extmarks
		priority = vim.hl.priorities.user - 1,
	},
	-- Source for how reference text is computed/updated/etc
	-- Uses content from Git index by default
	source = nil, -- NOTE(liu): be changed in config function
	-- Delays (in ms) defining asynchronous processes
	delay = {
		-- How much to wait before update following every text change
		text_change = 200,
	},
	-- Module mappings. Use `''` (empty string) to disable one.
	mappings = {
		-- 	-- Apply hunks inside a visual/operator region
		-- 	apply = "gh", -- WRITE TO DIFF SOURCE
		-- 	-- Reset hunks inside a visual/operator region
		-- 	reset = "gH", -- READ FROM DIFF SOURCE
		-- 	-- Hunk range textobject to be used inside operator
		textobject = "ah",
		-- 	-- Go to hunk range in corresponding direction
		-- 	goto_first = "[H",
		-- 	goto_prev = "[h",
		-- 	goto_next = "]h",
		-- 	goto_last = "]H",
	},
	-- Various options
	options = {
		-- Diff algorithm. See `:h vim.diff()`.
		algorithm = "histogram",
		-- Whether to use "indent heuristic". See `:h vim.diff()`.
		indent_heuristic = true,
		-- The amount of second-stage diff to align lines (in Neovim>=0.9)
		linematch = 60,
	},
})

vim.pack.add({ "https://github.com/tpope/vim-obsession" })
vim.cmd([[
	setglobal sessionoptions-=buffers 
	setglobal sessionoptions+=globals
	"setglobal sessionoptions-=curdir 
	"setglobal sessionoptions+=sesdir

	augroup liu.obsession
	  autocmd!
	  autocmd VimEnter * nested
			  \ if !argc() && empty(bufname()) && empty(v:this_session) && !&modified |
			  \   let s:session_paths = ['Session.vim', '.git/Session.vim', '.config/Session.vim'] |
			  \   for s:path in s:session_paths |
			  \     if filereadable(s:path) |
			  \       execute 'source' fnameescape(s:path) |
			  \       break |
			  \     endif |
			  \   endfor |
			  \ endif
	augroup END
]])

vim.pack.add({ "https://github.com/tpope/vim-dispatch" })
vim.g.dispatch_no_maps = false
vim.g.dispatch_compilers = {
	-- python
	["uv run"] = "python",
	["python3"] = "python",
	["python -m pytest"] = "pytest",
	["python3 -m pytest"] = "pytest",
	-- golang
	["go test"] = "gotest",
	["golangci-lint run"] = "go",
}
vim.cmd([[
	nmap `<bs> <cmd>AbortDispatch<cr>

	augroup liu.dispatch
	  autocmd!
	  autocmd BufReadPost *
	  \ if getline(1) =~# '^#!' |
	  \   let b:dispatch =
	  \       matchstr(getline(1), '#!\%(/usr/bin/env \+\)\=\zs.*') . ' %:S' |
	  \   let b:start = '-wait=always ' . b:dispatch |
	  \ endif

	  autocmd FileType python
	  \ if getline(1) =~# '^# /// script' |
	  \   let b:dispatch = 'uv run --script %' |
	  \   let b:start = '-wait=always ' . b:dispatch |
	  \ endif
	augroup END
]])

vim.pack.add({ "https://github.com/tpope/vim-sleuth" })
vim.pack.add({ "https://github.com/tpope/vim-eunuch" })
vim.pack.add({ "https://github.com/tpope/vim-rsi" })

-- vim.pack.add({ "https://github.com/tpope/vim-projectionist" })
vim.pack.add({ "https://github.com/gh-liu/vim-projectionist" })
vim.cmd([[
	nnoremap <leader>aa <cmd>A<cr>
	nnoremap <leader>as <cmd>AS<cr>
	nnoremap <leader>ac <cmd>AV<cr>
]])

local aug_qf_ref = vim.api.nvim_create_augroup("liu.quickfix.reflector", { clear = true })
vim.pack.add({ "https://github.com/stefandtw/quickfix-reflector.vim" })
vim.api.nvim_create_autocmd("VimLeavePre", {
	group = aug_qf_ref,
	callback = function(args)
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_get_name(buf):match("quickfix-%a") then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	end,
})

vim.pack.add({ "https://github.com/numEricL/table.vim" })

--====== tools
vim.pack.add({ "https://github.com/tpope/vim-dadbod" })

local aug_kulala = vim.api.nvim_create_augroup("liu.kulala", { clear = true })
vim.pack.add({ "https://github.com/mistweaverco/kulala.nvim" }, { load = function() end })
vim.api.nvim_create_autocmd({ "BufReadPre" }, {
	group = aug_kulala,
	pattern = "*.http",
	callback = function(ev)
		vim.cmd.packadd("kulala.nvim")
		require("kulala").setup({
			global_keymaps = false,
			certificates = {},
			custom_dynamic_variables = {},
			additional_curl_options = { "--noproxy", "*" },
			ui = {},
		})
	end,
	once = true,
})
