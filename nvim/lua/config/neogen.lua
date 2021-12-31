local neogen = require("neogen")
local map = require("utils").map

neogen.setup({
  enabled = true,
})
map("n", "<leader>d", '<cmd>lua require("neogen").generate()<cr>')
map(
  "n",
  "<leader>df",
  '<cmd>lua require("neogen").generate({ type = "func" })<cr>'
)
map(
  "n",
  "<leader>dc",
  '<cmd>lua require("neogen").generate({ type = "class" })<cr>'
)
