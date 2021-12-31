local utils = require("utils")
-- local map = utils.map
local autocmd = utils.autocmd

-- vim.g.rainbow#blacklist = [121]
-- vim.g.rainbow#pairs = [['(', ')'], ['[', ']'], ['{', '}']]

autocmd("rainbow_parentheses", { [[VimEnter * RainbowParentheses]] }, true)
