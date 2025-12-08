-- NOTE: completion, pairs, doc gen
return {
	{
		"saghen/blink.cmp",
		-- lazy = false,
		-- event = "InsertEnter",
		event = "VeryLazy",
		version = "*", -- download pre-built binaries
		dependencies = {
			"nvim-mini/mini.icons",
			"rafamadriz/friendly-snippets",
		},
		opts = {
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
				menu = {
					border = vim.o.winborder,
					winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
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
				},
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
					window = {
						border = vim.o.winborder,
						winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
					},
				},
				-- ghost_text = {},
			},
			signature = { -- NOTE: !experimental
				enabled = true,
				window = {
					border = vim.o.winborder,
					winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
				},
			},
			sources = {
				default = function(ctx)
					local buf_providers = vim.b.blink_cmp_provider
					if buf_providers then
						if type(buf_providers) == "table" then
							return buf_providers
						end
						if type(buf_providers) == "string" then
							return vim.split(buf_providers, ",")
						end
					end

					-- local node = vim.treesitter.get_node()
					-- if node and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type()) then
					-- 	return { "buffer" }
					-- end

					local default = { "lsp", "path", "snippets", "buffer" }
					local buf_provider_inherit = vim.b.blink_cmp_provider_inherit
					if buf_provider_inherit then
						local providers = {}
						if type(buf_provider_inherit) == "table" then
							providers = buf_provider_inherit
						end
						if type(buf_provider_inherit) == "string" then
							providers = vim.split(buf_provider_inherit, ",")
						end
						for _, p in ipairs(providers) do
							table.insert(default, p)
						end
					end
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
		},
	},
	{
		"nvim-mini/mini.pairs",
		enabled = true,
		event = "InsertEnter",
		keys = {
			{
				"yoP",
				function()
					vim.g.minipairs_disable = not vim.g.minipairs_disable
					if vim.g.minipairs_disable then
						vim.notify("Disabled auto pairs", vim.log.levels.WARN)
					else
						vim.notify("Enabled auto pairs", vim.log.levels.WARN)
					end

					-- When a bracket is inserted, briefly jump to the matching one.
					vim.o.showmatch = vim.g.minipairs_disable
				end,
				desc = "Toggle mini.pairs",
			},
		},
		opts = {
			modes = { insert = true, command = true, terminal = false },
			-- skip autopair when next character is one of these
			skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
			-- skip autopair when the cursor is inside these treesitter nodes
			skip_ts = { "string" },
			-- skip autopair when next character is closing pair
			-- and there are more closing pairs than opening pairs
			skip_unbalanced = true,
			-- better deal with markdown code blocks
			markdown = true,
		},
		config = function(self, opts)
			local pairs = require("mini.pairs")
			pairs.setup(opts)

			local open = pairs.open
			pairs.open = function(pair, neigh_pattern)
				if vim.fn.getcmdline() ~= "" then
					return open(pair, neigh_pattern)
				end
				-- open, close
				local o, c = pair:sub(1, 1), pair:sub(2, 2)
				local line = vim.api.nvim_get_current_line()
				local cursor = vim.api.nvim_win_get_cursor(0)
				local next = line:sub(cursor[2] + 1, cursor[2] + 1)
				local before = line:sub(1, cursor[2])
				if opts.markdown and o == "`" and vim.bo.filetype == "markdown" and before:match("^%s*``") then
					return "`\n```" .. vim.api.nvim_replace_termcodes("<up>", true, true, true)
				end
				if opts.skip_next and next ~= "" and next:match(opts.skip_next) then
					return o
				end
				if opts.skip_ts and #opts.skip_ts > 0 then
					local ok, captures =
						pcall(vim.treesitter.get_captures_at_pos, 0, cursor[1] - 1, math.max(cursor[2] - 1, 0))
					for _, capture in ipairs(ok and captures or {}) do
						if vim.tbl_contains(opts.skip_ts, capture.capture) then
							return o
						end
					end
				end
				if opts.skip_unbalanced and next == c and c ~= o then
					local _, count_open = line:gsub(vim.pesc(pair:sub(1, 1)), "")
					local _, count_close = line:gsub(vim.pesc(pair:sub(2, 2)), "")
					if count_close > count_open then
						return o
					end
				end
				return open(pair, neigh_pattern)
			end

			-- for filetypes {{{3
			local pairs_by_fts = {
				zig = function(buf)
					pairs.map_buf(buf, "i", "|", { action = "closeopen", pair = "||", register = { cr = false } })
				end,
				rust = function(buf)
					pairs.map_buf(buf, "i", "|", { action = "closeopen", pair = "||", register = { cr = false } })
					pairs.map_buf(buf, "i", "<", { action = "open", pair = "<>", register = { cr = false } })
					pairs.map_buf(buf, "i", ">", { action = "close", pair = "<>", register = { cr = false } })
				end,
			}

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("liu/mini.pairs/for_fts", { clear = true }),
				pattern = vim.tbl_keys(pairs_by_fts),
				callback = function(ev)
					local buf = ev.buf
					pairs_by_fts[ev.match](buf)
				end,
				desc = "set mini pairs for fts",
			})
			-- }}}
		end,
	},
	{
		"danymat/neogen",
		cmd = { "Neogen" },
		opts = {
			snippet_engine = "nvim", ---@type "luasnip"|"nvim"|"mini"
		},
	},
}
