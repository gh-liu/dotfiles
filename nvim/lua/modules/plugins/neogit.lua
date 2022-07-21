local neogit = require("neogit")

neogit.setup({
  disable_signs = false,
  integrations = {
    diffview = true,
  },
})

as.map("n", "<leader>gg", neogit.open)
