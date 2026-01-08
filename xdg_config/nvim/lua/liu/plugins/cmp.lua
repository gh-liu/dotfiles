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

					local default = { "lsp", "path", "snippets", "buffer", "omni" }
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
		},
		config = function(self, opts)
			local pairs = require("mini.pairs")
			pairs.setup(opts)

			-- =====================================================================
			-- Enhanced pairs.open with smart skip logic
			-- Inspired by LazyVim's mini.pairs configuration
			-- =====================================================================

			---@class MiniPairsEnhanceConfig
			---@field skip_next string? Pattern to skip autopair when next char matches
			---@field skip_ts string[]? Treesitter nodes where autopair is skipped
			---@field skip_unbalanced boolean? Skip when brackets are unbalanced
			---@field markdown boolean? Enable markdown code block auto-completion
			local enhance_config = {
				-- Skip autopair when next character is one of these:
				-- %w = word char, %% = %, %' = ', %[ = [, %" = ", %. = ., %` = `, %$ = $
				skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
				-- Skip autopair when cursor is inside these treesitter capture nodes
				skip_ts = { "string" },
				-- Skip autopair when closing bracket count > opening bracket count
				skip_unbalanced = true,
				-- Auto-complete markdown fenced code block when typing third backtick
				markdown = true,
			}

			--- Check if autopair should be skipped based on next character
			---@param next_char string The character after cursor
			---@return boolean
			local function should_skip_next(next_char)
				if not enhance_config.skip_next then
					return false
				end
				return next_char ~= "" and next_char:match(enhance_config.skip_next) ~= nil
			end

			--- Check if cursor is inside a treesitter node that should skip autopair
			---@param cursor integer[] {row, col} 1-indexed cursor position
			---@return boolean
			local function should_skip_ts(cursor)
				local skip_ts = enhance_config.skip_ts
				if not skip_ts or #skip_ts == 0 then
					return false
				end
				-- Get treesitter captures at cursor position (0-indexed row, col)
				local ok, captures =
					pcall(vim.treesitter.get_captures_at_pos, 0, cursor[1] - 1, math.max(cursor[2] - 1, 0))
				if not ok then
					return false
				end
				for _, capture in ipairs(captures) do
					if vim.tbl_contains(skip_ts, capture.capture) then
						return true
					end
				end
				return false
			end

			--- Check if brackets are unbalanced and should skip autopair
			--- Example: "foo)" has more ) than (, so typing ( should not add )
			---@param line string Current line content
			---@param open_char string Opening bracket character
			---@param close_char string Closing bracket character
			---@param next_char string Character after cursor
			---@return boolean
			local function should_skip_unbalanced(line, open_char, close_char, next_char)
				if not enhance_config.skip_unbalanced then
					return false
				end
				-- Only check when next char is closing bracket and pair is asymmetric
				if next_char ~= close_char or close_char == open_char then
					return false
				end
				local _, count_open = line:gsub(vim.pesc(open_char), "")
				local _, count_close = line:gsub(vim.pesc(close_char), "")
				return count_close > count_open
			end

			--- Handle markdown fenced code block auto-completion
			--- When typing ``` at line start, auto-complete to a code block
			---@param open_char string The character being typed
			---@param before string Text before cursor on current line
			---@return string? Returns key sequence if handled, nil otherwise
			local function handle_markdown_codeblock(open_char, before)
				if not enhance_config.markdown then
					return nil
				end
				-- Check: typing `, in markdown, line starts with ``
				if open_char == "`" and vim.bo.filetype == "markdown" and before:match("^%s*``") then
					-- Complete to: ```\n```<up> (cursor ends up between the fences)
					return "`\n```" .. vim.api.nvim_replace_termcodes("<up>", true, true, true)
				end
				return nil
			end

			-- Wrap original pairs.open with enhanced logic
			local original_open = pairs.open
			pairs.open = function(pair, neigh_pattern)
				-- In command-line mode, use original behavior
				if vim.fn.getcmdline() ~= "" then
					return original_open(pair, neigh_pattern)
				end

				local open_char, close_char = pair:sub(1, 1), pair:sub(2, 2)
				local line = vim.api.nvim_get_current_line()
				local cursor = vim.api.nvim_win_get_cursor(0)
				local next_char = line:sub(cursor[2] + 1, cursor[2] + 1)
				local before = line:sub(1, cursor[2])

				-- 1. Handle markdown code block special case
				local md_result = handle_markdown_codeblock(open_char, before)
				if md_result then
					return md_result
				end
				-- 2. Skip if next character matches skip pattern (e.g., word char)
				if should_skip_next(next_char) then
					return open_char
				end
				-- 3. Skip if inside a treesitter node (e.g., string literal)
				if should_skip_ts(cursor) then
					return open_char
				end
				-- 4. Skip if brackets are unbalanced
				if should_skip_unbalanced(line, open_char, close_char, next_char) then
					return open_char
				end

				return original_open(pair, neigh_pattern)
			end

			-- =====================================================================
			-- Filetype-specific pair mappings
			-- =====================================================================
			local pairs_by_fts = {
				zig = function(buf)
					-- Zig uses || for closure parameters
					pairs.map_buf(buf, "i", "|", { action = "closeopen", pair = "||", register = { cr = false } })
				end,
				rust = function(buf)
					-- Rust uses || for closure parameters
					pairs.map_buf(buf, "i", "|", { action = "closeopen", pair = "||", register = { cr = false } })
					-- Rust uses <> for generics
					pairs.map_buf(buf, "i", "<", { action = "open", pair = "<>", register = { cr = false } })
					pairs.map_buf(buf, "i", ">", { action = "close", pair = "<>", register = { cr = false } })
				end,
			}

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("liu/mini.pairs/for_fts", { clear = true }),
				pattern = vim.tbl_keys(pairs_by_fts),
				callback = function(ev)
					pairs_by_fts[ev.match](ev.buf)
				end,
				desc = "Setup filetype-specific mini.pairs mappings",
			})
		end,
	},
	{
		"danymat/neogen",
		cmd = { "Neogen" },
		keys = {
			{ "ydd", "<cmd>Neogen<cr>", desc = "Generate annotation (auto-detect)" },
			{ "ydf", "<cmd>Neogen func<cr>", desc = "Generate function doc" },
			{ "ydc", "<cmd>Neogen class<cr>", desc = "Generate class doc" },
			{ "ydt", "<cmd>Neogen type<cr>", desc = "Generate type doc" },
			{ "ydF", "<cmd>Neogen file<cr>", desc = "Generate file doc" },
		},
		opts = {
			snippet_engine = "nvim", ---@type "luasnip"|"nvim"|"mini"
		},
	},
}
