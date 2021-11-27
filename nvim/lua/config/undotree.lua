local utils = require 'utils'
local map = utils.map
-- local autocmd = utils.autocmd

vim.g.undotree_SetFocusWhenToggle = 1
vim.g.undotree_WindowLayout = 2

map('n', 'U', [[<cmd>UndotreeToggle<cr>]])