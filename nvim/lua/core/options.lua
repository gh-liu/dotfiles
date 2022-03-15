local o, wo, bo = vim.o, vim.wo, vim.bo

local opt = as.opt

local cmd = vim.api.nvim_command

-- Leader/local leader
vim.g.mapleader = [[,]]
vim.g.maplocalleader = [[,]]

-- Settings
local buffer = { o, bo }
local window = { o, wo }

opt("termguicolors", true)
opt("lazyredraw", true)
opt("splitbelow", true)
opt("updatetime", 200)
opt("showmatch", true)
opt("hidden", true)

opt("shortmess", o.shortmess .. "c")
-- opt("shada", [['20,<50,s10,h,/100]])

opt("mouse", "nivh")

opt("scrolloff", 7)
opt("sidescrolloff", 7)

opt("wrap", false)
opt("whichwrap", vim.o.whichwrap .. "<,>,h,l")

opt("cursorline", true, window)
opt("guicursor", [[n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50]])

-- opt('wildignore', '*.o,*~,*.pyc')
-- opt('wildmode', 'longest,full')

-- search
opt("magic", true)
opt("hlsearch", true)
opt("incsearch", true)
opt("ignorecase", true)
opt("smartcase", true)
opt("synmaxcol", 500, buffer)

-- indent
opt("tabstop", 2, buffer)
opt("softtabstop", 0, buffer)
opt("expandtab", true, buffer)
opt("shiftwidth", 2, buffer)
opt("smartindent", true, buffer)

-- signcolumn
opt("signcolumn", "yes:1", window)
opt("number", true, window)
opt("relativenumber", true, window)

-- status line
opt("laststatus", 2)
opt("showmode", false)
opt("modeline", false, buffer)

-- popup menu
opt("pumheight", 12)
-- opt('completeopt', 'menuone,noselect') -- Set completeopt to have a better completion experience

-- fold
opt("foldmethod", "indent")
opt("foldlevel", 99)

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
