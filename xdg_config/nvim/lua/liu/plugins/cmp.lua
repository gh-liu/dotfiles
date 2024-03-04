local api = vim.api

local cmp = require("cmp")
local luasnip = require("luasnip")
local vim_snippet = vim.snippet

-- Luasnip
do
	local types = require("luasnip.util.types")
	luasnip.config.setup({
		keep_roots = false,
		link_roots = false,
		link_children = true,
		update_events = { "InsertLeave" },
		region_check_events = { "InsertEnter" },
		delete_check_events = { "TextChanged" },
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
				-- 	passive = {
				-- 		virt_text = { { " ○ ", "LuasnipInsertNodePassive" } },
				-- 		virt_text_pos = "inline",
				-- 	},
				-- 	active = {
				-- 		virt_text = { { " ● ", "LuasnipInsertNodeActive" } },
				-- 		virt_text_pos = "inline",
				-- 	},
				unvisited = {
					virt_text = { { "|", "LuasnipChoiceNodeUnvisited" } },
					virt_text_pos = "inline",
				},
			},
			[types.exitNode] = {
				-- passive = {
				-- 	virt_text = { { " ⇳ ", "Comment" } },
				-- 	virt_text_pos = "inline",
				-- },
				-- active = {
				-- 	virt_text = { { " ⬍ ", "WarningMsg" } },
				-- 	virt_text_pos = "inline",
				-- },
				unvisited = {
					virt_text = { { "|", "LuasnipExitNodeUnvisited" } },
					virt_text_pos = "inline",
				},
			},
		},
	})

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
		LuasnipChoiceNodeUnvisited = {
			fg = config.colors.gray,
			italic = true,
		},
		LuasnipExitNodeUnvisited = {
			fg = config.colors.gray,
			bold = true,
		},
	})

	require("luasnip.loaders.from_lua").load({ paths = (vim.fn.stdpath("config") .. "/snippets/luasnip") })
	require("luasnip.loaders.from_vscode").lazy_load()

	vim.api.nvim_create_user_command("LuaSnipEdit", function()
		require("luasnip.loaders").edit_snippet_files({})
	end, { nargs = 0 })

	vim.api.nvim_create_autocmd("ModeChanged", {
		group = vim.api.nvim_create_augroup("liu/unlink_snippet", { clear = true }),
		desc = "Cancel the snippet session when leaving insert mode",
		pattern = { "s:n", "i:*" },
		callback = function(args)
			if
				luasnip.session
				and luasnip.session.current_nodes[args.buf]
				and not luasnip.session.jump_active
				and not luasnip.choice_active()
			then
				luasnip.unlink_current()
			end

			if vim_snippet.active() then
				vim_snippet.exit()
			end
		end,
	})
end

-- cmp
do
	local source_labels = {
		buffer = "[BUF]",
		nvim_lsp = "[LSP]", -- unknown source https://github.com/hrsh7th/nvim-cmp/issues/290#issuecomment-939327970
		luasnip = "[SNIP]",
		path = "[PATH]",
		-- cmdline = "[CMD]",
		omni = "[OMNI]",
		git = "[GIT]",
	}

	local function has_words_before()
		local line, col = unpack(api.nvim_win_get_cursor(0))
		return (
			(col ~= 0) and (((api.nvim_buf_get_lines(0, (line - 1), line, true))[1]):sub(col, col):match("%s") == nil)
		)
	end

	local winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None"

	---@diagnostic disable-next-line: missing-fields
	cmp.setup({
		snippet = {
			expand = function(args)
				luasnip.lsp_expand(args.body) -- For `luasnip` users.
			end,
		},
		window = {
			---@diagnostic disable-next-line: missing-fields
			completion = {
				border = config.borders,
				winhighlight = winhighlight,
			},
			---@diagnostic disable-next-line: missing-fields
			documentation = {
				border = config.borders,
				winhighlight = winhighlight,
				max_height = math.floor(vim.o.lines * 0.5),
				max_width = math.floor(vim.o.columns * 0.4),
			},
		},
		sources = {
			{ name = "nvim_lsp" },
			{ name = "luasnip" },
			{
				name = "buffer",
				keyword_length = 3,
				option = {
					get_bufnrs = function()
						local bufs = {}
						for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
							table.insert(bufs, api.nvim_win_get_buf(win))
						end
						return bufs
					end,
				},
			},
			{ name = "path" },
			{ name = "nvim_lsp_signature_help" },
		},
		---@diagnostic disable-next-line: missing-fields
		formatting = {
			fields = { "abbr", "kind", "menu" },
			format = function(entry, item)
				local kind = item.kind
				local symbol = (config.icons.completion_item_kinds)[kind]
				if symbol then
					item.kind = symbol.icon .. kind
					item.kind_hl_group = symbol.hl
				end
				item.menu = (source_labels[entry.source.name] or "")
				return item
			end,
		},
		mapping = cmp.mapping.preset.insert({
			["<C-b>"] = cmp.mapping.scroll_docs(-4),
			["<C-f>"] = cmp.mapping.scroll_docs(4),

			["<CR>"] = cmp.mapping.confirm({
				behavior = cmp.ConfirmBehavior.Replace,
				select = true,
			}),
			["<C-e>"] = cmp.mapping.abort(),
			-- ["/"] = cmp.mapping.close(),

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
			["<C-h>"] = cmp.mapping(function(fallback)
				-- native snippet
				if vim_snippet.active() and vim_snippet.jumpable(-1) then
					return vim_snippet.jump(-1)
				end
				-- luaship snippet
				if luasnip.in_snippet() and luasnip.jumpable(-1) then
					return luasnip.jump(-1)
				end
				return fallback()
			end, { "i", "s" }),
			["<C-l>"] = cmp.mapping(function(fallback)
				-- native snippet
				if vim_snippet.active() and vim_snippet.jumpable(1) then
					return vim_snippet.jump(1)
				end
				-- luaship snippet
				if luasnip.in_snippet() and luasnip.jumpable(1) then
					return luasnip.jump(1)
				end
				return fallback()
			end, { "i", "s" }),
		}),
	})

	-- ft: query
	cmp.setup.filetype({ "query" }, {
		sources = cmp.config.sources({
			{ name = "omni" },
		}),
	})

	local highlights = {}
	for key, value in pairs(config.icons.completion_item_kinds) do
		highlights["CmpItemKind" .. key] = { link = value.hl }
	end
	set_hls(highlights)
end
