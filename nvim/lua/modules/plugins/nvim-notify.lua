require("notify").setup({
  stages = "fade_in_slide_out",
  timeout = 1000,
  on_open = function(win)
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(
        win,
        { border = as.lazy_require("core.config").border.rounded }
      )
    end
  end,
  max_width = function()
    return math.floor(vim.o.columns * 0.8)
  end,
  max_height = function()
    return math.floor(vim.o.lines * 0.8)
  end,
})

vim.notify = require("notify")
