local utils = require('utils')
local map = utils.map
-- local autocmd = utils.autocmd

vim.g.tagbar_autoclose = 1
vim.g.tagbar_autofocus = 2
vim.g.tagbar_position = 'leftabove vertical'
vim.g.tagbar_width = 30
vim.g.tagbar_compact = 1
vim.g.tagbar_autofocus = 2
vim.g.tagbar_autofocus = 2
vim.g.tagbar_autofocus = 2

-- https://github.com/preservim/tagbar/wiki#markdown
-- vim.g:tagbar_type_markdown = {
--   \ 'ctagstype'	: 'markdown',
--   \ 'kinds'		: [
--       \ 'c:chapter:0:1',
--       \ 's:section:0:1',
--       \ 'S:subsection:0:1',
--       \ 't:subsubsection:0:1',
--       \ 'T:l4subsection:0:1',
--       \ 'u:l5subsection:0:1',
--   \ ],
--   \ 'sro'			: '""',
--   \ 'kind2scope'	: {
--       \ 'c' : 'chapter',
--       \ 's' : 'section',
--       \ 'S' : 'subsection',
--       \ 't' : 'subsubsection',
--       \ 'T' : 'l4subsection',
--   \ },
--   \ 'scope2kind'	: {
--       \ 'chapter' : 'c',
--       \ 'section' : 's',
--       \ 'subsection' : 'S',
--       \ 'subsubsection' : 't',
--       \ 'l4subsection' : 'T',
--   \ },
--   \ }

map('n', 'T', [[<cmd>TagbarToggle<cr>]])
