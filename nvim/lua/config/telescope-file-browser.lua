require("telescope").setup({
  extensions = {
    file_browser = {
      theme = "ivy",
    },
  },
})

require("telescope").load_extension("file_browser")

vim.api.nvim_set_keymap(
  "n",
  "<C-n>",
  ":Telescope file_browser<cr>",
  { noremap = true, silent = true }
)
