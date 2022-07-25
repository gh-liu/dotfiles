local hints = require("lsp-inlayhints")

hints.setup({
  only_current_line = true,
  only_current_line_autocmd = "CursorHold",
  show_parameter_hints = true,
  show_variable_name = true,
  -- parameter_hints_prefix = "<- ",
  -- type_hints_prefix = "-> ",
  max_len_align = false,
  -- other_hints_remove_colon = true,
  max_len_align_padding = 1,
  right_align = false,
  right_align_padding = 7,
  highlight = "Comment",
})
