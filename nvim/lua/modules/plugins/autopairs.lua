local npairs = require("nvim-autopairs")

npairs.setup({
  check_ts = true,
  disable_filetype = { "TelescopePrompt" },
  enable_check_bracket_line = false,
})

-- If you want insert `(` after select function or method item
local cmp = require("cmp")
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
cmp.event:on(
  "confirm_done",
  cmp_autopairs.on_confirm_done({
    map_char = {
      tex = "{",
    },
  })
)
