local o, wo, bo = vim.o, vim.wo, vim.bo

local opt = require("utils").opt

-- Leader/local leader
vim.g.mapleader = [[,]]
vim.g.maplocalleader = [[,]]

-- Settings
local buffer = { o, bo }
local window = { o, wo }

opt("mouse", "nivh")
-- opt('textwidth', 100, buffer)
opt("scrolloff", 7)

-- opt('wildignore', '*.o,*~,*.pyc')
-- opt('wildmode', 'longest,full')
-- opt('whichwrap', vim.o.whichwrap .. '<,>,h,l')

opt("inccommand", "nosplit")
opt("lazyredraw", true)
opt("showmatch", true)

opt("magic", true)
opt("hlsearch", true)
opt("incsearch", true)
opt("ignorecase", true)
opt("smartcase", true)

opt("tabstop", 2, buffer)
opt("softtabstop", 0, buffer)
opt("expandtab", true, buffer)
opt("shiftwidth", 2, buffer)

opt("number", true, window)
opt("relativenumber", true, window)

opt("smartindent", true, buffer)
opt("laststatus", 2)
opt("showmode", false)
opt("shada", [['20,<50,s10,h,/100]])

opt("hidden", true)
opt("shortmess", o.shortmess .. "c")

opt("joinspaces", false)
opt("guicursor", [[n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50]])
opt("updatetime", 300)

-- opt('conceallevel', 2, window)
opt("concealcursor", "nc", window)

opt("previewheight", 5)
opt("undofile", true, buffer)
opt("synmaxcol", 500, buffer)
opt("display", "msgsep")

opt("cursorline", true, window)
opt("modeline", false, buffer)

opt("pumheight", 12)

opt("signcolumn", "yes:1", window)

-- opt('splitright', true)
opt("splitbelow", true)

-- opt('completeopt', 'menuone,noselect') -- Set completeopt to have a better completion experience

opt("termguicolors", true)

-- fold
-- opt('foldmethod', 'indent')
opt("foldlevel", 99)

-- vim.opt.list = true
-- vim.opt.listchars = {
--     space = "⋅",
--     eol = "↴"
-- }

-- ====== built-in plugins ======
-- local map = require("utils").map

-- Disable some we don't want
local disabled_built_ins = {
  "gzip",
  "man",
  "matchparen",
  "shada_plugin",
  "tarPlugin",
  "tar",
  "zipPlugin",
  "zip",
  "netrwPlugin",
}
for i = 1, #disabled_built_ins do
  vim.g["loaded_" .. disabled_built_ins[i]] = 1
end
-- netrw settings
-- g.netrw_banner = 1
-- g.netrw_browse_split = 4
-- g.netrw_altv = 1
-- vim.g.netrw_liststyle = 3
-- g.netrw_winsize = 25
-- map("n", "<C-n>", "<cmd>Vexplore<cr>")
