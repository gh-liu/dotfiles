local utils = require 'utils'
-- local opt = utils.opt
local map = utils.map
-- local autocmd = utils.autocmd

-- <C-/> 
map('v', '<C-_>', 'gc',  {silent = true, noremap = true} )
map('n', '<C-_>', 'gcc',  {silent = true, noremap = true} ) 
map('i', '<C-_>', '<C-o>gcc',  {silent = true, noremap = true} )