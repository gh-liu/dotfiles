local cmp = {
	{
		"hrsh7th/nvim-cmp",
		event = { "InsertEnter" },
		dependencies = {
			"hrsh7th/cmp-path",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-cmdline",
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-nvim-lsp-signature-help",
			"hrsh7th/cmp-omni",
		},
		config = function()
			local cmp = require("cmp")
			local luasnip = require("luasnip")

			local compare = cmp.config.compare

			local function has_words_before()
				local line, col = unpack(vim.api.nvim_win_get_cursor(0))
				return (
					(col ~= 0)
					and (((vim.api.nvim_buf_get_lines(0, (line - 1), line, true))[1]):sub(col, col):match("%s") == nil)
				)
			end

			local source_labels = {
				buffer = "[BUF]",
				nvim_lsp = "[LSP]",
				luasnip = "[SNIP]",
				path = "[PATH]",
				cmdline = "[CMD]",
			}

			cmp.setup({
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				preselect = cmp.PreselectMode.Item,
				mapping = cmp.mapping.preset.insert({
					["<C-u>"] = cmp.mapping.scroll_docs(-4),
					["<C-d>"] = cmp.mapping.scroll_docs(4),
					["<CR>"] = cmp.mapping.confirm({
						behavior = cmp.ConfirmBehavior.Replace,
						select = false,
					}),
					["<Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							return cmp.select_next_item()
						elseif has_words_before() then
							return cmp.complete()
						else
							return fallback()
						end
					end, { "i" }),
					["<S-Tab>"] = cmp.mapping(function(fallback)
						if cmp.visible() then
							return cmp.select_prev_item()
						else
							return fallback()
						end
					end, { "i" }),
					-- luasnip choice
					["<C-j>"] = cmp.mapping(function(fallback)
						if luasnip.choice_active() then
							return luasnip.change_choice(1)
						else
							return fallback()
						end
					end, { "i", "s" }),
					["<c-k>"] = cmp.mapping(function(fallback)
						if luasnip.choice_active() then
							return luasnip.change_choice(-1)
						else
							return fallback()
						end
					end, { "i", "s" }),
					-- luaship snippet jump
					["<C-h>"] = cmp.mapping(function(fallback)
						if luasnip.in_snippet() and luasnip.jumpable(-1) then
							return luasnip.jump(-1)
						else
							return fallback()
						end
					end, { "i", "s" }),
					["<C-l>"] = cmp.mapping(function(fallback)
						if luasnip.in_snippet() and luasnip.jumpable(1) then
							return luasnip.jump(1)
						else
							return fallback()
						end
					end, { "i", "s" }),
				}),
				sources = {
					{ name = "nvim_lsp" },
					{ name = "luasnip" },
					{ name = "nvim_lsp_signature_help" },
					{ name = "buffer", keyword_length = 3 }, -- don't complete from buffer right away
					{ name = "path" },
				},
				sorting = {
					comparators = {
						compare.score, -- score = score + ((#sources - (source_index - 1)) * sorting.priority_weight)
						compare.locality,
						compare.recently_used,
					},
				},
				window = {
					completion = { border = config.borders },
					documentation = { border = config.borders },
				},
				formatting = {
					fields = { "abbr", "kind", "menu" },
					format = function(entry, item)
						local icon = (config.kind_icons)[item.kind] or ""
						local kind_abbr = item.kind

						item.kind = kind_abbr
						item.kind_hl_group = "None"
						item.menu = (source_labels[entry.source.name] or "")

						return item
					end,
				},
			})

			local simpleformat = function(entry, item)
				local icon = (config.kind_icons)[item.kind] or ""
				item.kind = ""
				item.kind_hl_group = "None"
				item.menu = (source_labels[entry.source.name] or "")
				return item
			end

			cmp.setup.cmdline({ "/", "?" }, {
				mapping = cmp.mapping.preset.cmdline(),
				formatting = {
					fields = { "abbr", "menu" },
					format = simpleformat,
				},
				sources = { { name = "buffer" } },
			})

			cmp.setup.cmdline(":", {
				-- completion = { keyword_length = 3 },
				mapping = cmp.mapping.preset.cmdline(),
				formatting = {
					fields = { "abbr", "menu" },
					format = simpleformat,
				},
				sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
			})

			-- Complete vim.ui.input()
			cmp.setup.cmdline("@", {
				completion = { keyword_length = 3 },
				mapping = cmp.mapping.preset.cmdline(),
				formatting = {
					fields = { "abbr", "menu" },
					format = simpleformat,
				},
				sources = cmp.config.sources({
					{ name = "path" },
					-- { name = "buffer" },
				}),
			})

			-- cmp.setup.filetype("dap-repl", {
			-- 	sources = cmp.config.sources({
			-- 		{
			-- 			name = "buffer",
			-- 			option = {
			-- 				get_bufnrs = function()
			-- 					return vim.api.nvim_list_bufs()
			-- 				end,
			-- 			},
			-- 		},
			-- 	}),
			-- })
		end,
	},
	-- snip
	{
		"L3MON4D3/LuaSnip",
		event = "InsertEnter",
		dependencies = {
			"saadparwaiz1/cmp_luasnip",
			"rafamadriz/friendly-snippets",
		},
		config = function()
			local ls = require("luasnip")
			local types = require("luasnip.util.types")
			local from_lua = require("luasnip.loaders.from_lua")
			local from_vsc = require("luasnip.loaders.from_vscode")

			set_hls({
				LuasnipInsertNodeActive = {
					fg = config.colors.green,
				},
				LuasnipInsertNodePassive = {
					fg = config.colors.blue,
				},
				LuasnipChoiceNodeActive = {
					fg = config.colors.red,
				},
				LuasnipChoiceNodePassive = {
					fg = config.colors.blue,
				},
			})

			ls.config.setup({
				history = true,
				update_events = { "InsertLeave" },
				region_check_events = { "InsertEnter" },
				delete_check_events = { "InsertLeave" },
				-- store_selection_keys = "<Tab>",
				enable_autosnippets = false,
				ext_opts = {
					[types.choiceNode] = {
						passive = {
							virt_text = { { " ⇦ ", "LuasnipChoiceNodePassive" } },
							virt_text_pos = "inline",
						},
						active = {
							virt_text = { { " ⬅ ", "LuasnipChoiceNodeActive" } },
							virt_text_pos = "inline",
						},
					},
					[types.insertNode] = {
						passive = {
							virt_text = { { " ○ ", "LuasnipInsertNodePassive" } },
							virt_text_pos = "inline",
						},
						active = {
							virt_text = { { " ● ", "LuasnipInsertNodeActive" } },
							virt_text_pos = "inline",
						},
					},
					-- [types.exitNode] = {
					-- 	passive = {
					-- 		virt_text = { { " ⇳ ", "Comment" } },
					-- 		virt_text_pos = "inline",
					-- 	},
					-- 	active = {
					-- 		virt_text = { { " ⬍ ", "WarningMsg" } },
					-- 		virt_text_pos = "inline",
					-- 	},
					-- },
				},
			})

			from_lua.load({ paths = (vim.fn.stdpath("config") .. "/snippets/luasnip") })
			from_vsc.lazy_load()

			vim.api.nvim_create_user_command("LuaSnipEdit", from_lua.edit_snippet_files, {})
		end,
	},
}
return cmp
