local fn = vim.fn
local opt = vim.opt

vim.g.mapleader = [[,]]
vim.g.maplocalleader = [[,]]
vim.api.nvim_command("filetype plugin indent on")

-----------------------------------------------------------------------------//
-- Message output on vim actions {{{1
-----------------------------------------------------------------------------//
opt.shortmess = {
  t = true, -- truncate file messages at start
  A = true, -- ignore annoying swap file messages
  o = true, -- file-read message overwrites previous
  O = true, -- file-read message overwrites previous
  T = true, -- truncate non-file messages in middle
  f = true, -- (file x of x) instead of just (x of x
  F = true, -- Don't give file info when editing a file, NOTE: this breaks autocommand messages
  s = true,
  c = true,
  W = true, -- Don't show [w] or written when writing
}
-- }}}
-----------------------------------------------------------------------------//
-- Timings {{{1
-----------------------------------------------------------------------------//
opt.updatetime = 300
opt.timeout = true
opt.timeoutlen = 500
opt.ttimeoutlen = 10
-- }}}
-----------------------------------------------------------------------------//
-- Window splitting and buffers {{{1
-----------------------------------------------------------------------------//
opt.splitbelow = true
opt.splitright = true
opt.eadirection = "hor"
-- exclude usetab as we do not want to jump to buffers in already open tabs
-- do not use split or vsplit to ensure we don't open any new windows
vim.o.switchbuf = "useopen,uselast"
opt.fillchars = {
  fold = " ",
  eob = " ", -- suppress ~ at EndOfBuffer
  diff = "╱", -- alternatives = ⣿ ░ ─
  msgsep = " ", -- alternatives: ‾ ─
  foldopen = "▾",
  foldsep = "│",
  foldclose = "▸",
}
-- }}}
-----------------------------------------------------------------------------//
-- Diff {{{1
-----------------------------------------------------------------------------//
-- Use in vertical diff mode, blank lines to keep sides aligned, Ignore whitespace changes
opt.diffopt = opt.diffopt
  + {
    "vertical",
    "iwhite",
    "hiddenoff",
    "foldcolumn:0",
    "context:4",
    "algorithm:histogram",
    "indent-heuristic",
  }
-- }}}
-----------------------------------------------------------------------------//
-- Format Options {{{1
-----------------------------------------------------------------------------//
opt.formatoptions = {
  ["1"] = true,
  ["2"] = true, -- Use indent from 2nd line of a paragraph
  q = true, -- continue comments with gq"
  c = true, -- Auto-wrap comments using textwidth
  r = true, -- Continue comments when pressing Enter
  n = true, -- Recognize numbered lists
  t = false, -- autowrap lines using text width value
  j = true, -- remove a comment leader when joining lines.
  -- Only break if the line was not longer than 'textwidth' when the insert
  -- started and only at a white character that has been entered during the
  -- current insert command.
  l = true,
  v = true,
}
-- }}}
-----------------------------------------------------------------------------//
-- Folds {{{1
-----------------------------------------------------------------------------//
-- opt.foldopen = opt.foldopen + 'search'
-- opt.foldlevelstart = 3
-- opt.foldexpr = 'nvim_treesitter#foldexpr()'
-- opt.foldmethod = 'expr'
-- }}}
-----------------------------------------------------------------------------//
-- Grepprg {{{1
-----------------------------------------------------------------------------//
-- Use faster grep alternatives if possible
if vim.fn.executable("rg") then
  vim.o.grepprg = [[rg --glob "!.git" --no-heading --vimgrep --follow $*]]
  opt.grepformat = opt.grepformat ^ { "%f:%l:%c:%m" }
elseif vim.fn.executable("ag") then
  vim.o.grepprg = [[ag --nogroup --nocolor --vimgrep]]
  opt.grepformat = opt.grepformat ^ { "%f:%l:%c:%m" }
end
-- }}}
-----------------------------------------------------------------------------//
-- Wild and file globbing stuff in command mode {{{1
-----------------------------------------------------------------------------//
-- opt.wildcharm = fn.char2nr(gh.replace_termcodes([[<Tab>]]))
opt.wildmode = "longest:full,full" -- Shows a menu bar as opposed to an enormous list
opt.wildignorecase = true -- Ignore case when completing file names and directories
-- Binary
opt.wildignore = {
  "*.out",
  "*.o",
  "*.obj",
  "*.class",
}
opt.wildoptions = "pum"
opt.pumblend = 3 -- Make popup window translucent
-- }}}
-----------------------------------------------------------------------------//
-- Display {{{1
-----------------------------------------------------------------------------//
opt.conceallevel = 2
opt.breakindentopt = "sbr"
opt.linebreak = true -- lines wrap at words rather than random characters
opt.synmaxcol = 1024 -- don't syntax highlight long lines
opt.signcolumn = "no"
opt.number = true
opt.relativenumber = true
opt.ruler = false
opt.cmdheight = 2 -- Set command line height to two lines
opt.showbreak = [[↪ ]] -- Options include -> '…', '↳ ', '→','↪ '
opt.cc = "80"
-- }}}
-----------------------------------------------------------------------------//
-- List chars {{{1
-----------------------------------------------------------------------------//
opt.list = true -- invisible chars
opt.listchars = {
  eol = nil, -- eol = "↴",
  tab = "  ", -- Alternatives: '▷▷', -- tab = "▸\\",
  extends = "›", -- Alternatives: … »
  precedes = "‹", -- Alternatives: … «
  trail = "•", -- BULLET (U+2022, UTF-8: E2 80 A2)
  space = "⋅",
}
-- }}}
-----------------------------------------------------------------------------//
-- Indentation {{{1
-----------------------------------------------------------------------------//
opt.wrap = true
opt.wrapmargin = 2
opt.textwidth = 80
opt.autoindent = true
opt.shiftround = true
opt.expandtab = true
opt.shiftwidth = 2
opt.whichwrap = "b,s,<,>,h,l"
-- }}}
-----------------------------------------------------------------------------//
-- Misc {{{1
-----------------------------------------------------------------------------//
opt.pumheight = 15
opt.confirm = true -- make vim prompt me to save before doing destructive things
-- opt.completeopt = { 'menuone', 'noselect' }
opt.gdefault = true
opt.hlsearch = true
opt.autowriteall = true -- automatically :write before running commands and changing files
opt.clipboard = { "unnamedplus" }
opt.laststatus = 3
opt.termguicolors = true
-- opt.guifont = 'Fira Code Regular Nerd Font Complete Mono:h14'
-- }}}
-----------------------------------------------------------------------------//
-- Cursor {{{1
-----------------------------------------------------------------------------//
-- This is from the help docs, it enables mode shapes, "Cursor" highlight, and blinking
opt.guicursor = {
  [[n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50]],
  [[a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor]],
  [[sm:block-blinkwait175-blinkoff150-blinkon175]],
}

opt.cursorline = true
opt.cursorlineopt = "screenline,number"
-- }}}
-----------------------------------------------------------------------------//
-- Title {{{1
-----------------------------------------------------------------------------//
-- opt.titlestring = ' ❐ %{fnamemodify(getcwd(), ":t")}'
-- opt.titleold = fn.fnamemodify(vim.loop.os_getenv('SHELL'), ':t')
-- opt.title = true
-- opt.titlelen = 70
-- }}}
-----------------------------------------------------------------------------//
-- Utilities {{{1
-----------------------------------------------------------------------------//
opt.showmode = false
-- NOTE: Don't remember help files since that will error if they are from a lazy loaded plugin
-- opt.sessionoptions = {
--   'globals',
--   'buffers',
--   'curdir',
--   'winpos',
--   'tabpages',
-- }
opt.viewoptions = { "cursor", "folds" } -- save/restore just these (with `:{mk,load}view`)
opt.virtualedit = "block" -- allow cursor to move where there is no text in visual block mode
--}}}
-------------------------------------------------------------------------------
-- BACKUP AND SWAPS {{{
-------------------------------------------------------------------------------
opt.backup = false
opt.undofile = true
opt.swapfile = false
--}}}
-----------------------------------------------------------------------------//
-- Match and search {{{1
-----------------------------------------------------------------------------//
opt.ignorecase = true
opt.smartcase = true
opt.wrapscan = true -- Searches wrap around the end of the file
opt.scrolloff = 9
opt.sidescrolloff = 10
opt.sidescroll = 1
--}}}
-----------------------------------------------------------------------------//
-- Spelling {{{1
-----------------------------------------------------------------------------//
-- opt.spellsuggest:prepend({ 12 })
-- opt.spelloptions = 'camel'
-- opt.spellcapcheck = '' -- don't check for capital letters at start of sentence
-- opt.fileformats = { 'unix', 'mac', 'dos' }
-- opt.spelllang:append('programming')
--}}}
-----------------------------------------------------------------------------//
-- Mouse {{{1
-----------------------------------------------------------------------------//
opt.mouse = "a"
opt.mousefocus = true
--}}}
-----------------------------------------------------------------------------//
-- Builtin {{{1
-----------------------------------------------------------------------------//
vim.g.loaded_gzip = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1

vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_2html_plugin = 1

vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_rrhelper = 1

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

-- netrw settings
-- g.netrw_banner = 1
-- g.netrw_browse_split = 4
-- g.netrw_altv = 1
-- vim.g.netrw_liststyle = 3
-- g.netrw_winsize = 25
-- map("n", "<C-n>", "<cmd>Vexplore<cr>")

vim.g.did_load_filetypes = 1
--}}}
-----------------------------------------------------------------------------//

-- vim:foldmethod=marker
