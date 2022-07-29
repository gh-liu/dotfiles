-- vim.cmd [[highlight IndentBlanklineContextChar guifg=#8AADF4 gui=nocombine]]

require("indent_blankline").setup({
  char = "┆",
  space_char_blankline = " ",
  show_current_context = true,
  -- context_char_blankline = "┃",
})
