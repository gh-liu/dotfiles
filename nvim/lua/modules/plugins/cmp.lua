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

local neogen_exist, neogen = pcall(require, "neogen")

local function select_next(fallback)
  if cmp.visible() then
    cmp.select_next_item()
  elseif luasnip.expand_or_jumpable() then
    luasnip.expand_or_jump()
  elseif neogen_exist and neogen.jumpable() then
    neogen.jump_next()
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
  elseif neogen_exist and neogen.jumpable() then
    neogen.jump_prev()
  else
    fallback()
  end
end

local function select_next_j(fallback)
  if cmp.visible() then
    cmp.select_next_item()
  else
    fallback()
  end
end

local function select_previous_k(fallback)
  if cmp.visible() then
    cmp.select_prev_item()
  else
    fallback()
  end
end

cmp.setup({
  formatting = {
    format = function(entry, vim_item)
      vim_item.menu = ({
        buffer = "[Buf]",
        nvim_lsp = "[LSP]",
        nvim_lua = "[Lua]",
        luasnip = "[Snip]",
        path = "[Path]",
      })[entry.source.name]

      vim_item.kind = as.lazy_require("core.config").symbol_icons[vim_item.kind]
        .. " "
        .. vim_item.kind

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
      select = true,
    }),
    ["<esc>"] = cmp.mapping({
      i = cmp.mapping.abort(),
      c = cmp.mapping.close(),
    }),
    ["<Tab>"] = cmp.mapping(select_next, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(select_previous, { "i", "s" }),
    ["<C-j>"] = cmp.mapping(select_next_j, { "i", "s" }),
    ["<C-k>"] = cmp.mapping(select_previous_k, { "i", "s" }),
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
    -- completion = cmp.config.window.bordered(),
    documentation = {
      border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    },
  },
})

-- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline("/", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = "buffer" },
  },
})

-- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
cmp.setup.cmdline(":", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = "path" },
  }, {
    { name = "cmdline" },
  }),
})

-- If you want insert `(` after select function or method item
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
cmp.event:on(
  "confirm_done",
  cmp_autopairs.on_confirm_done({
    map_char = {
      tex = "{",
    },
  })
)
