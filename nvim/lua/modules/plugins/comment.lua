require("Comment").setup()
-- <C-/>
local opts = {
  silent = true,
}

vim.keymap.set(
  { "i", "n" },
  "<C-_>",
  require("Comment.api").toggle_current_linewise,
  opts
)

vim.keymap.set(
  "x",
  "<C-_>",
  '<ESC><CMD>lua require("Comment.api").toggle_linewise_op(vim.fn.visualmode())<CR>',
  opts
)
