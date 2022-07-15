local map = as.map

require("hop").setup({
  keys = "etovxqpdygfblzhckisuran",
})

map("n", "<leader>w", "<cmd>HopWordAC<cr>")
-- map('n', '<leader>s', "<cmd>HopChar1<cr>")
-- map('n', '<leader>k', "<cmd>HopLineStartBC<cr>")
-- map('n', '<leader>j', "<cmd>HopLineStartAC<cr>")
-- map('v', '<leader>k', "<cmd>HopLineStartBC<cr>")
-- map('v', '<leader>j', "<cmd>HopLineStartAC<cr>")
-- map('n', '<leader>h', "<cmd>HopWordBC<cr>")
-- map('n', '<leader>l', "<cmd>HopWordAC<cr>")
-- map('v', '<leader>h', "<cmd>HopWordBC<cr>")
-- map('v', '<leader>l', "<cmd>HopWordAC<cr>")

map(
  "o",
  "f",
  "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true })<cr>",
  {}
)
map(
  "o",
  "F",
  "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true })<cr>",
  {}
)
map(
  "o",
  "t",
  "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.AFTER_CURSOR, current_line_only = true, hint_offset = -1 })<cr>",
  {}
)
map(
  "o",
  "T",
  "<cmd>lua require'hop'.hint_char1({ direction = require'hop.hint'.HintDirection.BEFORE_CURSOR, current_line_only = true, hint_offset = 1 })<cr>",
  {}
)
