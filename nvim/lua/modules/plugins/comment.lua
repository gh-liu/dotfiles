require("Comment").setup()
-- <C-/>
local opts = {
  silent = true,
}
as.map("v", "<C-_>", "gc", opts)
as.map("n", "<C-_>", "gcc", opts)
as.map(
  "i",
  "<C-_>",
  "<cmd>lua require('Comment.api').toggle_current_linewise()<cr>",
  opts
)
