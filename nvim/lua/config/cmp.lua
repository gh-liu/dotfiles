local has_words_before = function()
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local cmp = require('cmp')
local luasnip = require('luasnip')
-- local lspkind = require('lspkind')
local function select_next(fallback)
    if cmp.visible() then
        cmp.select_next_item()
    elseif luasnip.expand_or_jumpable() then
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
    -- completion = {
    --     completeopt = 'menu,menuone,noinsert'
    -- },
    -- formatting = {
    --   format = lspkind.cmp_format({with_text = false, maxwidth = 50})
    -- },
    snippet = {
        expand = function(args)
            luasnip.lsp_expand(args.body)
        end
    },
    mapping = {
        ['<cr>'] = cmp.mapping.confirm({
            select = true
        }),
        ['<esc>'] = cmp.mapping({
            i = cmp.mapping.abort(),
            c = cmp.mapping.close()
        }),
        ["<Tab>"] = cmp.mapping(select_next, {"i", "s"}),
        ["<S-Tab>"] = cmp.mapping(select_previous, {"i", "s"}),
        ["<C-j>"] = cmp.mapping(select_next_j, {"i", "s"}),
        ["<C-k>"] = cmp.mapping(select_previous_k, {"i", "s"}),
        ['<C-y>'] = cmp.config.disable
    },
    sources = {{
        name = 'buffer'
    }, {
        name = 'nvim_lsp'
    }, {
        name = 'luasnip'
    }, {
        name = 'path'
    }},
    experimental = {
        -- ghost_text = true
    }
})

-- If you want insert `(` after select function or method item
local cmp_autopairs = require('nvim-autopairs.completion.cmp')
cmp.event:on('confirm_done', cmp_autopairs.on_confirm_done({
    map_char = {
        tex = '{'
    }
}))

