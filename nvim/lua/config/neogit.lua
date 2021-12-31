local utils = require("utils")
local map = utils.map

require("neogit").setup({
  disable_signs = false,
  integrations = {
    diffview = true,
  },
})
