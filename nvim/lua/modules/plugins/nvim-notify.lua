require("notify").setup({
  -- Animation style (see below for details)
  stages = "slide",

  -- Default timeout for notifications
  timeout = 500,
})

vim.notify = require("notify")
