local api = vim.api

-- Luasnip {{{1
local ls = require("luasnip")
local types = require("luasnip.util.types")

ls.config.setup({
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

require("luasnip.loaders.from_lua").load({ paths = (vim.fn.stdpath("config") .. "/snippets/luasnip") })

require("luasnip.loaders.from_vscode").lazy_load()

vim.api.nvim_create_user_command("LuaSnipEdit", function()
	require("luasnip.loaders").edit_snippet_files({})
end, {})

-- }}}

-- cmp {{{1
local cmp = require("cmp")
local luasnip = require("luasnip")

local source_labels = {
	buffer = "[BUF]",
	nvim_lsp = "[LSP]",
	luasnip = "[SNIP]",
	path = "[PATH]",
	cmdline = "[CMD]",
	omni = "[OMNI]",
	git = "[GIT]",
}

local function has_words_before()
	local line, col = unpack(api.nvim_win_get_cursor(0))
	return ((col ~= 0) and (((api.nvim_buf_get_lines(0, (line - 1), line, true))[1]):sub(col, col):match("%s") == nil))
end

---@diagnostic disable-next-line: missing-fields
cmp.setup({
	snippet = {
		expand = function(args)
			require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
		end,
	},
	window = {
		---@diagnostic disable-next-line: missing-fields
		completion = {
			border = config.borders,
			winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
		},
		---@diagnostic disable-next-line: missing-fields
		documentation = {
			border = config.borders,
			winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
		},
	},
	sources = {
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
		{ name = "nvim_lsp_signature_help" },
		{ name = "buffer", keyword_length = 3 }, -- don't complete from buffer right away
		{ name = "path" },
	},
	---@diagnostic disable-next-line: missing-fields
	formatting = {
		fields = { "abbr", "kind", "menu" },
		format = function(entry, item)
			local kind = item.kind
			local symbol = (config.icons.symbol_kinds)[kind]
			if symbol then
				item.kind = symbol.icon .. " " .. kind
				item.kind_hl_group = symbol.hl
			end
			item.menu = (source_labels[entry.source.name] or "")
			return item
		end,
	},
	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-e>"] = cmp.mapping.abort(),
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
})

local simple_formatting = {
	fields = { "abbr", "kind" },
	format = function(entry, item)
		local kind_abbr = item.kind
		item.kind = kind_abbr
		item.kind_hl_group = "None"
		return item
	end,
}

-- Use buffer source for `/` and `?` (if you enabled `native_menu`, this won't work anymore).
---@diagnostic disable-next-line: missing-fields
cmp.setup.cmdline({ "/", "?" }, {
	mapping = cmp.mapping.preset.cmdline(),
	formatting = simple_formatting,
	sources = {
		{ name = "buffer" },
	},
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
---@diagnostic disable-next-line: missing-fields
cmp.setup.cmdline(":", {
	mapping = cmp.mapping.preset.cmdline(),
	formatting = simple_formatting,
	sources = cmp.config.sources({
		{ name = "path" },
	}, {
		{ name = "cmdline" },
	}),
	---@diagnostic disable-next-line: missing-fields
	completion = {
		autocomplete = false,
		completeopt = "menu,menuone,noselect",
	},
})

-- }}}

-- vim: foldmethod=marker
