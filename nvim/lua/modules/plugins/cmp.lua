local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0
    and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
        :sub(col, col)
        :match("%s")
      == nil
end

local cmp = require("cmp")
local luasnip = require("luasnip")

local config = gh.lazy_require("core.config")

local function select_next(fallback)
  if cmp.visible() then
    cmp.select_next_item()
  elseif luasnip.expand_or_locally_jumpable() then
    luasnip.expand_or_jump()
  elseif has_words_before() then
    cmp.complete()
  else
    fallback()
  end
end

local function select_previous(fallback)
  if cmp.visible() then
    cmp.select_prev_item()
  elseif luasnip.jumpable(-1) then
    luasnip.jump(-1)
  else
    fallback()
  end
end

local function select_next_j(fallback)
  if cmp.visible() then
    cmp.select_next_item()
  elseif luasnip.choice_active() then
    luasnip.change_choice(1)
  else
    fallback()
  end
end

local function select_previous_k(fallback)
  if cmp.visible() then
    cmp.select_prev_item()
  elseif luasnip.choice_active() then
    luasnip.change_choice(-1)
  else
    fallback()
  end
end

cmp.setup({
  formatting = {
    -- fields = { "kind", "abbr", "menu" },
    format = function(entry, vim_item)
      vim_item.menu = ({
        buffer = "[Buf]",
        nvim_lsp = "[LSP]",
        nvim_lua = "[Lua]",
        luasnip = "[Snip]",
        path = "[Path]",
        cmdline = "[Cmd]",
        cmdline_history = "[CHis]",
      })[entry.source.name]

      vim_item.kind = config.icons.kinds[vim_item.kind] .. " " .. vim_item.kind

      return vim_item
    end,
  },
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<cr>"] = cmp.mapping.confirm({
      -- select = true,
      -- behavior = cmp.ConfirmBehavior.Replace,
      select = false,
    }),
    ["<esc>"] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),
    ["<Tab>"] = cmp.mapping(select_next, { "i", "s", "c" }),
    ["<S-Tab>"] = cmp.mapping(select_previous, { "i", "s", "c" }),
    ["<C-j>"] = cmp.mapping(select_next_j, { "i", "s", "c" }),
    ["<C-k>"] = cmp.mapping(select_previous_k, { "i", "s", "c" }),
    ["<C-y>"] = cmp.config.disable,
  }),
  sources = {
    {
      name = "nvim_lsp",
    },
    {
      name = "luasnip",
    },
    { name = "nvim_lsp_signature_help" },
    {
      name = "buffer",
      option = {
        -- complete from visible buffers
        get_bufnrs = function()
          local bufs = {}
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            bufs[vim.api.nvim_win_get_buf(win)] = true
          end
          return vim.tbl_keys(bufs)
        end,
      },
    },
    {
      name = "path",
    },
  },
  window = {
    completion = {
      border = config.border.rounded,
      scrollbar = "┃",
      winhighlight = "Normal:Pmenu,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
    },
    documentation = {
      border = config.border.rounded,
      scrollbar = "┃",
      winhighlight = "Normal:Pmenu,FloatBorder:FloatBorder,CursorLine:Visual,Search:None",
    },
  },
})

local search_opts = {
  view = { entries = { name = "custom", selection_order = "near_cursor" } },
  sources = cmp.config.sources({
    { name = "nvim_lsp_document_symbol" },
  }, {
    { name = "buffer" },
  }),
}
cmp.setup.cmdline("/", search_opts)
cmp.setup.cmdline("?", search_opts)

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(":", {
  sources = cmp.config.sources({
    { name = "cmdline", keyword_pattern = [=[[^[:blank:]\!]*]=] },
    { name = "cmdline_history" },
    { name = "path" },
  }),
})
