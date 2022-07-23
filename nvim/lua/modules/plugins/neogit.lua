local neogit = require("neogit")

neogit.setup({
  disable_signs = false,
  integrations = {
    diffview = true,
  },
})

gh.map("n", "<leader>gg", neogit.open)
