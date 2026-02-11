local api = vim.api
local fn = vim.fn

---@alias MiniSearchMethod 'cover'|'cover_or_next'|'cover_or_prev'|'cover_or_nearest'|'next'|'prev'|'nearest'

return {
	-- Enhanced textobjects (a/i) for brackets, functions, classes, arguments, etc.
	{
		"nvim-mini/mini.ai",
		-- "wellle/targets.vim",
		dependencies = {
			{
				-- Textobjects based on Tree-sitter queries (acf/gc/etc)
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
	-- Add/delete/change surrounding characters (ys/cs/ds with quotes/brackets/tags)
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
						-- Link: [text][ref] with reference at EOF
						U = {
							input = { "%[().-()%]%b()" },
							output = function()
								local MiniSurround = require("mini.surround")
								local link = MiniSurround.user_input("Link")
								-- 1. Generate 3-char random ID
								local ref_id = ""
								for _ = 1, 3 do
									local r = math.random(36)
									ref_id = ref_id .. string.char(r <= 26 and 64 + r or 22 + r)
								end
								-- 2. Append reference to EOF
								local last_line = vim.api.nvim_buf_get_lines(0, -2, -1, false)[1] or ""
								local lines = last_line ~= "" and { "", "[" .. ref_id .. "]: " .. link }
									or { "[" .. ref_id .. "]: " .. link }
								vim.api.nvim_buf_set_lines(0, -1, -1, false, lines)
								return { left = "[", right = "][" .. ref_id .. "]" }
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
	-- Text operators: replace (dr), exchange (cx), evaluate (g=), multiply, sort
	{
		"nvim-mini/mini.operators",
		keys = {
			{ "dr", mode = { "n", "x" }, desc = "Replace text" },
			{ "dR", "<cmd>normal dr$<cr>", mode = { "n", "x" }, silent = true, desc = "Replace to end of line" },
			{ "cx", mode = { "n", "x" }, desc = "Exchange text" },
			{ "cX", "<cmd>normal cx$<cr>", mode = { "n", "x" }, silent = true, desc = "Exchange to end of line" },
			{ "g=", mode = { "n", "x" }, desc = "Evaluate expression" },
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
	-- Move line/selection in any direction with Alt+hjkl keys
	{
		"nvim-mini/mini.move",
		keys = {
			{ "<M-h>", mode = { "n", "x" }, desc = "Move left" },
			{ "<M-j>", mode = { "n", "x" }, desc = "Move down" },
			{ "<M-k>", mode = { "n", "x" }, desc = "Move up" },
			{ "<M-l>", mode = { "n", "x" }, desc = "Move right" },
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
	-- Align text on delimiter with interactive split/join operations
	{
		"nvim-mini/mini.align",
		keys = {
			{ "gl", mode = { "n", "x" }, desc = "Align" },
			{ "gL", mode = { "n", "x" }, desc = "Align with preview" },
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
	-- Smart increment/decrement with LSP-aware enum sequences and date patterns
	{
		"gh-liu/nvim-mobius",
		dev = true,
		keys = {
			{ "<C-a>", "<Plug>(MobiusIncrement)", mode = { "n", "v" }, desc = "Increment" },
			{ "<C-x>", "<Plug>(MobiusDecrement)", mode = { "n", "v" }, desc = "Decrement" },
			{ "g<C-a>", "<Plug>(MobiusIncrementSeq)", mode = { "n", "v" }, remap = true, desc = "Increment globally" },
			{ "g<C-x>", "<Plug>(MobiusDecrementSeq)", mode = { "n", "v" }, remap = true, desc = "Decrement globally" },
		},
		init = function()
			local ft_rules = {
				go = {
					true,
					function()
						return require("mobius.rules.lsp_enum")({
							symbol_kinds = {
								-- vim.lsp.protocol.CompletionItemKind.EnumMember,
								vim.lsp.protocol.CompletionItemKind.Constant,
							},
							exclude_labels = { "false", "true" },
						})
					end,
				},
			}
			vim.api.nvim_create_autocmd("FileType", {
				pattern = vim.tbl_keys(ft_rules),
				callback = function(args)
					vim.b.mobius_rules = ft_rules[args.match]
				end,
			})
		end,
	},
	{
		"monaqa/dial.nvim",
		-- overrides: default <C-a>/<C-x> behavior (increment/decrement)
		enabled = false,
		keys = {
			{ "<C-a>", "<Plug>(dial-increment)", mode = { "n", "v" }, desc = "Increment" },
			{ "<C-x>", "<Plug>(dial-decrement)", mode = { "n", "v" }, desc = "Decrement" },
			{ "g<C-a>", "<Plug>(dial-g-increment)", mode = { "n", "v" }, remap = true, desc = "Increment globally" },
			{ "g<C-x>", "<Plug>(dial-g-decrement)", mode = { "n", "v" }, remap = true, desc = "Decrement globally" },
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
				elements = { "GET", "POST", "PUT", "PATCH", "DELETE" },
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
				rust = vim.list_extend({
					augend.constant.new({ elements = { "&&", "||" }, word = false, cyclic = true }),
					augend.constant.new({ elements = { "Some", "None" }, word = true, cyclic = true }),
					augend.constant.new({ elements = { "Ok", "Err" }, word = true, cyclic = true }),
				}, default),
				toml = vim.list_extend({ augend.semver.alias.semver }, default),
				zig = vim.list_extend({
					augend.constant.new({ elements = { "and", "or" }, word = true, cyclic = true }),
				}, default),
				http = vim.list_extend({ http_methods }, default),
			})
		end,
	},
	-- Toggle between single-line and multi-line code blocks (arrays/objects/etc)
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
	-- Coercion (cr) for case conversion and Subvert for smart search/replace
	{
		"tpope/vim-abolish",
		-- event = "VeryLazy",
		init = function(self)
			vim.g.abolish_save_file = fn.stdpath("config") .. "/after/plugin/abolish.vim"

			-- NOTE: Extra Coercions
			-- https://github.com/tpope/vim-abolish/blob/dcbfe065297d31823561ba787f51056c147aa682/plugin/abolish.vim#L600
			vim.g.Abolish = {
				Coercions = {
					-- `crl{char}` = coerce + LSP rename
					-- Example: `crls` on `fooBar` → converts to `foo_bar` AND renames all references
					l = function(word)
						-- 1. Wait for user to input a coercion char (s, m, c, u, -, .)
						local ok, char = pcall(vim.fn.getcharstr)
						if not ok then
							return word
						end
						-- 2. Temporarily disable undo history
						local saved_undolevels = vim.bo.undolevels
						vim.bo.undolevels = -1
						-- 3. Execute the coercion (e.g., crs for snake_case)
						vim.cmd.normal({ "cr" .. char, bang = true })
						-- 4. Restore undo history
						vim.bo.undolevels = saved_undolevels
						-- 5. Get the converted word
						local word2 = vim.fn.expand("<cword>")
						-- 6. If word changed, undo local change and do LSP rename instead
						if word ~= word2 then
							local pos = vim.api.nvim_win_get_cursor(0)
							-- Undo the local change (LSP rename will handle all occurrences)
							vim.bo.undolevels = -1
							vim.cmd(([[s/%s/%s/eI]]):format(word2, word))
							vim.bo.undolevels = saved_undolevels
							vim.api.nvim_win_set_cursor(0, pos)
							-- Trigger LSP rename with the converted word
							vim.lsp.buf.rename(word2)
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
	-- Enable repeating of plugin mappings with dot command (.)
	{
		"tpope/vim-repeat",
		-- event = "VeryLazy",
	},
	-- Quick textobject selection via visual hints and single-key targets
	{
		"gh-liu/nvim-bullseye",
		dev = true,
		event = "VeryLazy",
	},
}
