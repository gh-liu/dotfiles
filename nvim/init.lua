require 'impatient'

local g = vim.g
local cmd = vim.cmd
local o, wo, bo = vim.o, vim.wo, vim.bo

local utils = require 'utils'
local opt = utils.opt
local map = utils.map
local autocmd = utils.autocmd

-- Leader/local leader
g.mapleader = [[,]]
g.maplocalleader = [[,]]

-- Disable some built-in plugins we don't want
local disabled_built_ins = {
  'gzip',
  'man',
  'matchit',
  'matchparen',
  'shada_plugin',
  'tarPlugin',
  'tar',
  'zipPlugin',
  'zip',
  'netrwPlugin',
}
for i = 1, 10 do
  g['loaded_' .. disabled_built_ins[i]] = 1
end

-- Settings
local buffer = { o, bo }
local window = { o, wo }
opt('textwidth', 100, buffer)
opt('scrolloff', 7)
opt('wildignore', '*.o,*~,*.pyc')
opt('wildmode', 'longest,full')
opt('whichwrap', vim.o.whichwrap .. '<,>,h,l')
opt('inccommand', 'nosplit')
opt('lazyredraw', true)
opt('showmatch', true)
opt('ignorecase', true)
opt('smartcase', true)
opt('tabstop', 2, buffer)
opt('softtabstop', 0, buffer)
opt('expandtab', true, buffer)
opt('shiftwidth', 2, buffer)
opt('number', true, window)
opt('relativenumber', true, window)
opt('smartindent', true, buffer)
opt('laststatus', 2)
opt('showmode', false)
opt('shada', [['20,<50,s10,h,/100]])
opt('hidden', true)
opt('shortmess', o.shortmess .. 'c')
opt('joinspaces', false)
opt('guicursor', [[n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50]])
opt('updatetime', 500)
opt('conceallevel', 2, window)
opt('concealcursor', 'nc', window)
opt('previewheight', 5)
opt('undofile', true, buffer)
opt('synmaxcol', 500, buffer)
opt('display', 'msgsep')
opt('cursorline', true, window)
opt('modeline', false, buffer)
opt('mouse', 'nivh')
opt('signcolumn', 'yes:1', window)

-- Colorscheme
opt('termguicolors', true)
opt('background', 'dark')
cmd [[colorscheme gruvbox-material]]

-- keybingdings

-- disable F1
map('', '<F1>', '<Esc>')

-- Switch ` and '
map('n', "'", '`')
map('n', "'", '`')

-- windows moving
map('n', '<C-h>', '<C-w>h', {silent = true} )
map('n', '<C-j>', '<C-w>j', {silent = true} )
map('n', '<C-k>', '<C-w>k', {silent = true} )
map('n', '<C-l>', '<C-w>l', {silent = true} )

-- moving in insert mode
map('i', '<C-h>', '<left>',  {silent = true, noremap = true} )
map('i', '<C-j>', '<down>',  {silent = true, noremap = true} )
map('i', '<C-k>', '<up>',    {silent = true, noremap = true} )
map('i', '<C-l>', '<right>', {silent = true, noremap = true} )
map('i', '<C-a>', '<HOME>',  {silent = true, noremap = true} )
map('i', '<C-e>', '<END>',   {silent = true, noremap = true} )

map('n', '[w', '<cmd>tabprevious<cr>')
map('n', ']w', '<cmd>tabnext<cr>')
map('n', '[W', '<cmd>tabfirst<cr>')
map('n', ']W', '<cmd>tablast<cr>')

map('n', '[b', '<cmd>bprevious<cr>')
map('n', ']b', '<cmd>bnext<cr>')
map('n', '[B', '<cmd>bfirst<cr>')
map('n', ']B', '<cmd>blast<cr>')

map('n', '[l', '<cmd>lprevious<cr>')
map('n', ']l', '<cmd>lnext<cr>')
map('n', '[L', '<cmd>lfirst<cr>')
map('n', ']L', '<cmd>llast<cr>')

map('n', '[q', '<cmd>cprevious<cr>')
map('n', ']q', '<cmd>cnext<cr>')
map('n', '[Q', '<cmd>cfirst<cr>')
map('n', ']Q', '<cmd>clast<cr>')

map('n', '[t', '<cmd>tprevious<cr>')
map('n', ']t', '<cmd>tnext<cr>')
map('n', '[T', '<cmd>tfirst<cr>')
map('n', ']T', '<cmd>tlast<cr>')

-- <Leader>[1-9] move to tab [1-9]
for i=1,9,1 do  
  map('n', '<leader>' .. i, i .. 'gt')
end  


map('n', 'j', 'gj')
map('n', 'k', 'gk')

-- Commands
cmd [[command! WhatHighlight :call util#syntax_stack()]]
cmd [[command! PackerInstall packadd packer.nvim | lua require('plugins').install()]]
cmd [[command! PackerUpdate packadd packer.nvim | lua require('plugins').update()]]
cmd [[command! PackerSync packadd packer.nvim | lua require('plugins').sync()]]
cmd [[command! PackerClean packadd packer.nvim | lua require('plugins').clean()]]
cmd [[command! PackerCompile packadd packer.nvim | lua require('plugins').compile()]]

