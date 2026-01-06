-- NOTE: textobject, operator, change.txt
local api = vim.api
local fn = vim.fn

---@alias MiniSearchMethod 'cover'|'cover_or_next'|'cover_or_prev'|'cover_or_nearest'|'next'|'prev'|'nearest'

return {
	{
		"nvim-mini/mini.ai",
		-- "wellle/targets.vim",
		dependencies = {
			{
				-- "nvim-treesitter/nvim-treesitter-textobjects",
				"gh-liu/nvim-treesitter-textobjects", -- NOTE: pull from main branch of upstream
				event = "VeryLazy",
			},
		},
		init = function()
			local ft_custom_textobject_fn = {
				markdown = function()
					local ai = require("mini.ai")
					local ts_gen = ai.gen_spec.treesitter
					return {
						C = ts_gen({
							a = "@fenced_code_block.outer",
							i = "@code_fence_content",
						}),
					}
				end,
			}
			vim.api.nvim_create_autocmd("FileType", {
				pattern = vim.tbl_keys(ft_custom_textobject_fn),
				callback = function(args)
					local ft = args.match
					vim.b[args.buf].miniai_config = {
						custom_textobjects = ft_custom_textobject_fn[ft](),
					}
				end,
			})
		end,
		keys = function()
			local expr_motion = function(side)
				local side_method = {
					left = "cover_or_prev",
					right = "cover_or_next",
				}
				return function()
					local ok, char = pcall(vim.fn.getcharstr)
					if not ok or char == vim.keycode("<ESC>") then
						return
					end
					return "<Cmd>lua "
						.. string.format(
							[[MiniAi.move_cursor('%s', 'a', %s, { n_times = %d, search_method = '%s' })]],
							side,
							vim.inspect(char),
							vim.v.count1,
							side_method[side]
						)
						.. "<CR>"
				end
			end

			return {
				{ "i", mode = { "o", "x" } },
				{ "a", mode = { "o", "x" } },
				{ "g[", expr_motion("left"), mode = { "o", "x", "n" }, expr = true },
				{ "g]", expr_motion("right"), mode = { "o", "x", "n" }, expr = true },
			}
		end,
		config = function(self, opts)
			local ai = require("mini.ai")
			local ts_gen = ai.gen_spec.treesitter
			ai.setup({
				silent = true,
				---@type MiniSearchMethod
				search_method = "cover",
				n_lines = 300,
				custom_textobjects = {
					-- Code blocks (if/for/while/etc.)
					o = ts_gen({
						a = { "@block.outer", "@conditional.outer", "@loop.outer" },
						i = { "@block.inner", "@conditional.inner", "@loop.inner" },
					}),
					-- Function
					f = ts_gen({ a = "@function.outer", i = "@function.inner" }, {}),
					-- Class
					c = ts_gen({ a = "@class.outer", i = "@class.inner" }, {}),
					-- NOTE: Use built-in `a` for argument/parameter instead of custom `P`
					-- Assignment: = for whole, l for lhs, r for rhs
					["="] = ts_gen({ a = "@assignment.outer", i = "@assignment.inner" }, {}),
					l = ts_gen({ a = "@assignment.lhs", i = "@assignment.lhs" }, {}), -- lhs (left-hand side)
					r = ts_gen({ a = "@assignment.rhs", i = "@assignment.rhs" }, {}), -- rhs (right-hand side)
					-- Function call (usage)
					u = ai.gen_spec.function_call(),
				},
				mappings = {
					-- -- Main textobject prefixes
					-- around = "a",
					-- inside = "i",

					-- around_next = "an",
					-- inside_next = "in",
					-- -- Disable next variants.
					-- around_next = "",
					-- inside_next = "",

					-- around_last = 'al',
					-- inside_last = 'il',
					-- Disable last variants.
					-- around_last = "",
					-- inside_last = "",

					-- Move cursor to corresponding edge of `a` textobject
					-- goto_left = "g[",
					-- goto_right = "g]",
					goto_left = "",
					goto_right = "",
				},
			})
		end,
	},
	{
		"nvim-mini/mini.surround",
		keys = {
			-- TODO: y will be used in x mode
			{ "ys", mode = { "x", "n" } },
			{ "ds", mode = { "n" } },
			{ "cs", mode = { "n" } },
			{ "yS", "ys$", remap = true },
			{ "yss", "ys_", remap = true },
			{ "sf" },
			{ "sF" },
			{ "sh" },
		},
		init = function()
			local ft_custom_surrounding_fn = {
				lua = function()
					return {
						s = {
							input = { "%[%[().-()%]%]" },
							output = { left = "[[", right = "]]" },
						},
					}
				end,
				markdown = function()
					return {
						-- Bold: **text**
						B = {
							input = { "%*%*().-()%*%*" },
							output = { left = "**", right = "**" },
						},
						-- Italic: *text*
						I = {
							input = { "%*().-()%*" },
							output = { left = "*", right = "*" },
						},
						-- Link: [text](url)
						U = {
							input = { "%[().-()%]%b()" },
							output = function()
								local MiniSurround = require("mini.surround")
								local link = MiniSurround.user_input("Link")
								return { left = "[", right = "](" .. link .. ")" }
							end,
						},
					}
				end,
			}
			vim.api.nvim_create_autocmd("FileType", {
				pattern = vim.tbl_keys(ft_custom_surrounding_fn),
				callback = function(args)
					local ft = args.match
					vim.b[args.buf].minisurround_config = {
						custom_surroundings = ft_custom_surrounding_fn[ft](),
					}
				end,
			})
		end,
		config = function(self, _)
			local keys = self.keys
			if not keys then
				return
			end

			local ts_input = require("mini.surround").gen_spec.input.treesitter
			local opts = {
				-- Module mappings. Use `''` (empty string) to disable one.
				mappings = {
					add = keys[1][1], -- Add surrounding in Normal and Visual modes
					delete = keys[2][1], -- Delete surrounding
					replace = keys[3][1], -- Replace surrounding

					find = keys[6][1], -- Find surrounding (to the right) - surround next
					find_left = keys[7][1], -- Find surrounding (to the left) - surround prev
					highlight = keys[8][1], -- Highlight surrounding - surround highlight
					update_n_lines = "", -- Update `n_lines`

					suffix_last = "l", -- Suffix to search with "prev" method
					suffix_next = "n", -- Suffix to search with "next" method
				},
				custom_textobjects = {
					f = ts_input({ outer = "@call.outer", inner = "@call.inner" }),
				},
				n_lines = 300,
				---@type MiniSearchMethod
				search_method = "cover",
			}

			require("mini.surround").setup(opts)
		end,
	},
	{
		"nvim-mini/mini.operators",
		keys = {
			-- NOTE: also change keys below
			{ "dr", mode = { "n", "x" } },
			{ "dR", "<cmd>normal dr$<cr>", silent = true },
			{ "cx", mode = { "n", "x" } },
			{ "cX", "<cmd>normal cx$<cr>", silent = true },
			{ "g=", mode = { "n", "x" } },
		},
		opts = {
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
		},
	},
	{
		"nvim-mini/mini.move",
		keys = {
			{ "<M-h>", mode = { "n", "x" } },
			{ "<M-j>", mode = { "n", "x" } },
			{ "<M-k>", mode = { "n", "x" } },
			{ "<M-l>", mode = { "n", "x" } },
		},
		config = function(self, opts)
			local keys = self.keys
			if not keys then
				return
			end

			require("mini.move").setup({
				mappings = {
					-- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
					left = keys[1][1],
					down = keys[2][1],
					up = keys[3][1],
					right = keys[4][1],
					-- Move current line in Normal mode
					line_left = keys[1][1],
					line_down = keys[2][1],
					line_up = keys[3][1],
					line_right = keys[4][1],
				},
			})
		end,
	},
	{
		"nvim-mini/mini.align",
		keys = {
			{ "gl", mode = { "n", "x" } },
			{ "gL", mode = { "n", "x" } },
		},
		config = function(self, opts)
			require("mini.align").setup({
				mappings = {
					start = self.keys[1][1],
					start_with_preview = self.keys[2][1],
				},
			})
		end,
	},
	{
		"monaqa/dial.nvim",
		keys = {
			{ "<C-a>", "<Plug>(dial-increment)", mode = { "n", "v" } },
			{ "<C-x>", "<Plug>(dial-decrement)", mode = { "n", "v" } },
			{ "g<C-a>", "<Plug>(dial-g-increment)", mode = { "n", "v" }, remap = true },
			{ "g<C-x>", "<Plug>(dial-g-decrement)", mode = { "n", "v" }, remap = true },
		},
		config = function()
			local config = require("dial.config")
			local augend = require("dial.augend")

			local default = {
				augend.date.new({ pattern = "%Y/%m/%d", default_kind = "day" }),
				augend.date.new({ pattern = "%Y-%m-%d", default_kind = "day" }),
				augend.integer.alias.decimal,
				augend.integer.alias.hex,
				augend.constant.alias.bool,
			}

			local http_methods = augend.constant.new({
				elements = { "GET", "POST", "PUT", "PATCH" },
				word = true,
				cyclic = true,
			})

			config.augends:register_group({
				default = default,
			})

			config.augends:on_filetype({
				python = vim.list_extend(
					{ augend.constant.new({ elements = { "True", "False" }, word = true, cyclic = true }) },
					default
				),
				go = vim.list_extend(
					{ augend.constant.new({ elements = { "&&", "||" }, word = false, cyclic = true }) },
					default
				),
				lua = vim.list_extend(
					{ augend.constant.new({ elements = { "and", "or" }, word = true, cyclic = true }) },
					default
				),
				markdown = vim.list_extend({ augend.misc.alias.markdown_header }, default),
				rust = vim.list_extend({}, default),
				toml = vim.list_extend({ augend.semver.alias.semver }, default),
				zig = vim.list_extend({}, default),
				http = vim.list_extend({ http_methods }, default),
			})
		end,
	},
	{
		"Wansmer/treesj",
		enabled = true,
		keys = {
			{
				"gJ",
				":TSJJoin<CR>",
				silent = true,
				desc = "joining blocks of code like arrays, hashes, statements, objects, dictionaries, etc.",
			},
			{
				"gS",
				":TSJSplit<CR>",
				silent = true,
				desc = "splitting blocks of code like arrays, hashes, statements, objects, dictionaries, etc.",
			},
		},
		cmd = { "TSJSplit", "TSJJoin" },
		opts = {
			use_default_keymaps = false,
			max_join_length = 300,
		},
	},
	{
		"tpope/vim-abolish",
		-- event = "VeryLazy",
		init = function(self)
			vim.g.abolish_save_file = fn.stdpath("config") .. "/after/plugin/abolish.vim"

			-- NOTE: Extra Coercions
			-- https://github.com/tpope/vim-abolish/blob/dcbfe065297d31823561ba787f51056c147aa682/plugin/abolish.vim#L600
			vim.g.Abolish = {
				Coercions = {
					l = function(word)
						local ok, char = pcall(vim.fn.getcharstr)
						if not ok then
							return word
						end
						vim.cmd("let b:tmp_undolevels = &l:undolevels | setlocal undolevels=-1")
						vim.cmd("normal cr" .. char)
						vim.cmd("let &l:undolevels = b:tmp_undolevels | unlet b:tmp_undolevels")
						local word2 = vim.fn.expand("<cword>")
						if word ~= word2 then
							local pos = vim.fn.getpos(".")
							vim.cmd("let b:tmp_undolevels = &l:undolevels | setlocal undolevels=-1")
							vim.cmd(string.format([[s/%s/%s/eI]], word2, word))
							vim.cmd("let &l:undolevels = b:tmp_undolevels | unlet b:tmp_undolevels")
							vim.fn.setpos(".", pos)

							vim.cmd(string.format('lua vim.lsp.buf.rename("%s")', word2))
						end
						return word
					end,
				},
			}

			-- vim.cmd([[
			-- 	nnoremap \s mS:Abolish -search
			-- 	nnoremap \S mS:%Subvert
			-- ]])
		end,
		keys = {
			"cr",
			-- { "crr", "<Plug>(abolish-coerce)", mode = { "n" } },
		},
		cmd = {
			"Abolish",
			"Subvert",
			"S",
		},
	},
	{
		"tpope/vim-repeat",
		-- event = "VeryLazy",
	},
	{
		"jpalardy/vim-slime",
		init = function()
			vim.g.slime_target = "neovim" ---@type 'neovim'|'tmux'
			-- vim.g.slime_target = "tmux"
			if vim.env.TMUX then
				-- NOTE: pane name
				-- https://github.com/jpalardy/vim-slime/blob/507107dd24c9b85721fa589462fd5068e0f70266/autoload/slime/targets/tmux.vim#L47
				-- tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{window_name}#{?window_active, (active),}'
				vim.g.slime_target = "tmux" ---@type 'neovim'|'tmux'
			end
			vim.g.slime_no_mappings = true
		end,
		-- ft = { "python" },
		config = function()
			vim.keymap.set("n", "gz", "<Plug>SlimeMotionSend", { remap = true, silent = false })
			vim.keymap.set("n", "gzz", "<Plug>SlimeLineSend", { remap = true, silent = false })
			vim.keymap.set("x", "gz", "<Plug>SlimeRegionSend", { remap = true, silent = false })
			vim.keymap.set("n", "gzc", "<Plug>SlimeConfig", { remap = true, silent = false })
			vim.keymap.set("n", "gz?", ":echo b:slime_config<cr>", { remap = true, silent = false })
		end,
	},
}
