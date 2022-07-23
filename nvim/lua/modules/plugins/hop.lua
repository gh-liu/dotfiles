local map = gh.map
local hop = require("hop")
local direction = require("hop.hint").HintDirection

hop.setup({
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

map("o", "f", function()
  hop.hint_char1({
    direction = direction.AFTER_CURSOR,
    current_line_only = true,
  })
end)

map("o", "F", function()
  hop.hint_char1({
    direction = direction.BEFORE_CURSOR,
    current_line_only = true,
  })
end)

map("o", "t", function()
  hop.hint_char1({
    direction = direction.AFTER_CURSOR,
    current_line_only = true,
    hint_offset = -1,
  })
end)

map("o", "T", function()
  hop.hint_char1({
    direction = direction.BEFORE_CURSOR,
    current_line_only = true,
    hint_offset = -1,
  })
end)
