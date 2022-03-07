require("neogit").setup({
  disable_signs = false,
  integrations = {
    diffview = true,
  },
})

as.map("n", "<leader>gg", ":Neogit <CR>")
