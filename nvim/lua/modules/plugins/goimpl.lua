require("telescope").load_extension("goimpl")

vim.api.nvim_set_keymap(
  "n",
  "<leader>im",
  [[<cmd>lua require('telescope').extensions.goimpl.goimpl{}<CR>]],
  {
    noremap = true,
    silent = true,
  }
)
