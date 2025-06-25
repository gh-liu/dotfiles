local config = require("liu.user_config")

return {
	{
		"saghen/blink.cmp",
		-- lazy = false,
		-- event = "InsertEnter",
		event = "VeryLazy",
		version = "*",
		dependencies = {
			"echasnovski/mini.icons",
			"rafamadriz/friendly-snippets",
		},
		opts = {
			enabled = function()
				return not (vim.bo.buftype == "prompt" or vim.fn.getcmdwintype() ~= "" or vim.b.completion)
			end,
			keymap = {
				-- preset = "default",
				--
				-- Available commands:
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
			sources = {
				default = function(ctx)
					local buf_providers = vim.b.blink_cmp_provider
					if buf_providers and type(buf_providers) == "table" then
						return buf_providers
					end

					-- local node = vim.treesitter.get_node()
					-- if node and vim.tbl_contains({ "comment", "line_comment", "block_comment" }, node:type()) then
					-- 	return { "buffer" }
					-- end

					return { "lsp", "path", "snippets", "buffer" }
				end,
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
			-- disable cmdline completions
			cmdline = { enabled = false },
			fuzzy = {
				implementation = "prefer_rust_with_warning",
			},
			completion = {
				menu = {
					border = config.borders,
					winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
					draw = {
						-- Use treesitter to highlight the label text
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
								ellipsis = false,
								text = function(ctx)
									local kind_icon, _, _ = require("mini.icons").get("lsp", ctx.kind)
									return kind_icon
								end,
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
						border = config.borders,
						winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
					},
				},
				accept = {
					-- Experimental auto-brackets support
					auto_brackets = {
						enabled = true,
					},
				},
			},
		},
	},
}
