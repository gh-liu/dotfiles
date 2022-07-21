local ls = require("luasnip")
local types = require("luasnip.util.types")

ls.config.set_config({
  history = false,
  region_check_events = "CursorMoved,CursorHold,InsertEnter",
  delete_check_events = "InsertLeave",
  ext_opts = {
    [types.choiceNode] = {
      passive = {
        virt_text = { { "<-", "Comment" } },
      },
      active = {
        virt_text = { { "<-", "Orange" } },
      },
    },
    [types.insertNode] = {
      passive = {
        virt_text = { { "●", "Comment" } },
      },
      active = {
        virt_text = { { "●", "Blue" } },
      },
    },
  },
  ext_base_prio = 300,
  ext_prio_increase = 1,
  enable_autosnippets = false,
  -- mapping for cutting selected text so it's usable as SELECT_DEDENT,
  -- SELECT_RAW or TM_SELECTED_TEXT (mapped via xmap).
  store_selection_keys = "<Tab>",
  -- luasnip uses this function to get the currently active filetype. This
  -- is the (rather uninteresting) default, but it's possible to use
  -- eg. treesitter for getting the current filetype by setting ft_func to
  -- require("luasnip.extras.filetype_functions").from_cursor (requires
  -- `nvim-treesitter/nvim-treesitter`). This allows correctly resolving
  -- the current filetype in eg. a markdown-code block or `vim.cmd()`.
  ft_func = function()
    return vim.split(vim.bo.filetype, ".", true)
  end,
})

ls.filetype_extend("all", { "_" })

require("luasnip.loaders.from_vscode").lazy_load()

local path = vim.fn.stdpath("config") .. "/lua/modules/plugins/luasnip/snippets"
require("luasnip.loaders.from_lua").load({ paths = path })

-- set keybinds for both INSERT and VISUAL.
-- vim.keymap.set({ "i", "n" }, "<M-n>", function()
--   ls.change_choice(1)
-- end, {})
-- vim.keymap.set({ "i", "n" }, "<M-p>", function()
--   ls.change_choice(-1)
-- end, {})

as.command("LuaSnipEdit", function()
  require("luasnip.loaders.from_lua").edit_snippet_files()
end)
