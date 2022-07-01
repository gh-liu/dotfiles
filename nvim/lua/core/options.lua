local o, wo, bo = vim.o, vim.wo, vim.bo

local opt = as.opt

local cmd = vim.api.nvim_command

-- Leader/local leader
vim.g.mapleader = [[,]]
vim.g.maplocalleader = [[,]]

local buffer = { o, bo }
local window = { o, wo }

-- MISC
opt("hidden", true) -- Hide unused buffers
opt("cc", 80) -- Set an 80 column boarder for good coding style
-- opt("lazyredraw", true)
opt("updatetime", 200)
opt("textwidth", 80)

-- PANE
opt("splitbelow", true) -- Always add new pane below
opt("splitright", true) -- Always add new pane on right

-- search and replace
opt("ignorecase", true) -- Case insensitive matching
opt("smartcase", true)
opt("hlsearch", true) -- Highlight search results
opt("inccommand", "split") -- Show replace result in a split screen before applying
opt("magic", true)
opt("incsearch", true)
opt("synmaxcol", 500, buffer)

-- tab and indentation
opt("tabstop", 2, buffer) -- Number of columns occupied by a tab character
opt("shiftwidth", 2, buffer) -- Width for
opt("softtabstop", 0, buffer) -- How far cursor travels by pressing tab
opt("expandtab", true, buffer) -- Converts tab to whitespace
opt("autoindent", true, buffer) -- Indent a new line the same amound as the line before it
-- opt("smartindent", true, buffer)

-- mouse and cursor
opt("mouse", "nivh")
opt("cursorline", true, window) -- Highlight current cursorline
opt("guicursor", [[n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50]])
-- scrolloff
opt("scrolloff", 7)
opt("sidescrolloff", 7)

-- sign column
opt("signcolumn", "yes:1", window)
-- line number
opt("number", true, window)
opt("relativenumber", true, window)

-- TERM SETTINGS
opt("termguicolors", true)

-- fold
opt("foldlevel", 999)
opt("foldmethod", "indent")

-- status line
opt("laststatus", 3)
opt("showmode", false)
opt("modeline", false, buffer)

-- wrap
opt("wrap", false)
opt("whichwrap", vim.o.whichwrap .. "<,>,h,l")

-- popup menu
opt("pumheight", 12)
-- opt('completeopt', 'menuone,noselect') -- Set completeopt to have a better completion experience

-- conceal
-- opt('conceallevel', 2, window)
opt("concealcursor", "nc", window)

-- filetype
cmd("filetype plugin indent on")

-- vim.opt.list = true
-- vim.opt.listchars = {
-- 	tab = "▸\\",
-- 	space = "⋅",
-- 	eol = "↴",
-- }

opt("undofile", true, buffer)
opt("previewheight", 5)
opt("display", "msgsep")
opt("showmatch", true)
opt("shortmess", o.shortmess .. "c")

-- ToggleMouse = function()
--   if vim.o.mouse == 'a' then
--     vim.wo.signcolumn = 'no'
--     vim.o.mouse = 'v'
--     vim.wo.number = false
--     print 'Mouse disabled'
--   else
--     vim.wo.signcolumn = 'yes'
--     vim.o.mouse = 'a'
--     vim.wo.number = true
--     print 'Mouse enabled'
--   end
-- end
--
-- vim.keymap.set('n', '<leader>bm', ToggleMouse)
