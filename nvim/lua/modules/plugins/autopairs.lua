local npairs = require("nvim-autopairs")

npairs.setup({
  check_ts = true,
})

local Rule = require("nvim-autopairs.rule")
local cond = require("nvim-autopairs.conds")
local ts_conds = require("nvim-autopairs.ts-conds")
