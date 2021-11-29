local neogen = require 'neogen'
local map = require('utils').map

neogen.setup {
    enabled = true
}
map('n', '<localleader>d', '<cmd>lua require("neogen").generate()<cr>')
map('n', '<localleader>df', '<cmd>lua require("neogen").generate({ type = "func" })<cr>')
map('n', '<localleader>dc', '<cmd>lua require("neogen").generate({ type = "class" })<cr>')
