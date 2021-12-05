require('packer_set')
-- require('impatient')

local g = vim.g
local cmd = vim.cmd
local o, wo, bo = vim.o, vim.wo, vim.bo

local utils = require('utils')
local opt = utils.opt
local map = utils.map
local autocmd = utils.autocmd

-- Leader/local leader
g.mapleader = [[,]]
g.maplocalleader = [[,]]

-- Settings
local buffer = {o, bo}
local window = {o, wo}

opt('mouse', 'nivh')
-- opt('textwidth', 100, buffer)
opt('scrolloff', 7)

opt('wildignore', '*.o,*~,*.pyc')
opt('wildmode', 'longest,full')
opt('whichwrap', vim.o.whichwrap .. '<,>,h,l')

opt('inccommand', 'nosplit')
opt('lazyredraw', true)
opt('showmatch', true)

opt('magic', true)
opt('hlsearch', true)
opt('incsearch', true)
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
opt('updatetime', 300)
opt('conceallevel', 2, window)
opt('concealcursor', 'nc', window)
opt('previewheight', 5)
opt('undofile', true, buffer)
opt('synmaxcol', 500, buffer)
opt('display', 'msgsep')
opt('cursorline', true, window)
opt('modeline', false, buffer)

opt('pumheight', 12)

opt('signcolumn', 'yes:1', window)

-- opt('splitright', true)
opt('splitbelow', true)

-- opt('completeopt', 'menuone,noselect') -- Set completeopt to have a better completion experience

-- Colorscheme
opt('termguicolors', true)
opt('background', 'dark')
cmd [[colorscheme gruvbox-material]]

-- fold
-- opt('foldmethod', 'indent')
opt('foldlevel', 99)
cmd [[
    au FileType tmux setlocal foldmethod=marker
    nnoremap <silent> <space> @=(foldlevel('.')?'za':"\<space>")<cr>
    ]]

-- Keybingdings
local silent = {
    silent = true
}

local silent_noremap = {
    silent = true,
    noremap = true
}

-- disable F1
map('', '<F1>', '<Esc>')

-- Switch ` and '
map('n', "'", '`')
map('n', "'", '`')

-- display lines move up or down
map('n', 'j', 'gj')
map('n', 'k', 'gk')

-- windows moving
map('n', '<C-h>', '<C-w>h', silent)
map('n', '<C-j>', '<C-w>j', silent)
map('n', '<C-k>', '<C-w>k', silent)
map('n', '<C-l>', '<C-w>l', silent)

-- moving in insert mode
map('i', '<C-h>', '<left>', silent_noremap)
map('i', '<C-j>', '<down>', silent_noremap)
map('i', '<C-k>', '<up>', silent_noremap)
map('i', '<C-l>', '<right>', silent_noremap)
map('i', '<C-a>', '<HOME>', silent_noremap)
map('i', '<C-e>', '<END>', silent_noremap)

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
for i = 1, 9, 1 do
    map('n', '<leader>' .. i, i .. 'gt')
end

map('n', '<c-a>', '<c-o>')

-- Do not show stupid q: window
map('n', 'q:', ':q')

-- qq to record, Q to replay
map('n', 'Q', '@q')

-- same as D
map('n', 'Y', 'y$')

-- Don't lose selection when shifting sidewards
map('x', '<', '<gv')
map('x', '>', '>gv')

-- Change window size
map('n', '<left>', '<c-w>>', silent)
map('n', '<right>', '<c-w><', silent)
map('n', '<up>', '<c-w>-', silent)
map('n', '<down>', '<c-w>+', silent)

-- Keep search pattern at the center of the screen
map('n', 'n', 'nzz', silent)
map('n', 'N', 'Nzz', silent)

-- Switch # *
map('n', '*', '#zz', silent)
map('n', '#', '*zz', silent)

-- moving in cmd-line mode
map('c', '<C-h>', '<left>')
map('c', '<C-j>', '<down>')
map('c', '<C-k>', '<up>')
map('c', '<C-l>', '<right>')
-- map('c', '<C-a>', '<HOME>')
-- map('c', '<C-e>', '<END>')

-- move to head or end of line in normal or visual mode
map('n', 'H', '^')
map('n', 'L', '$')
map('v', 'H', '^')
map('v', 'L', 'g_')

-- Edit alternate file
map('i', '<C-^>', '<C-o><C-^>')

-- Save
map('i', '<C-s>', '<C-O>:update<cr>')
map('n', '<C-s>', ':update<cr>')

-- Exit
map('i', '<C-q>', '<esc>:q<cr>')
map('n', '<C-q>', ':q<cr>')
map('v', '<C-q>', '<esc>')
map('n', '<Leader>q', ':q<cr>')
map('n', '<Leader>Q', ':qa!<cr>')

-- <Leader>c Close quickfix/location window
map('n', '<leader>c', ':cclose<bar>lclose<cr>', silent)

-- Edit $MYVIMRC
map('n', '<leader>ev', ':tabnew $MYVIMRC<cr>', silent)

map('i', 'jj', '<Esc>')

-- Autocommands
autocmd('misc_aucmds', {[[BufWinEnter * checktime]], [[TextYankPost * silent! lua vim.highlight.on_yank()]],
                        [[FileType qf set nobuflisted ]]}, true)

-- autocmd('packer_user_config', {[[BufWritePost plugins.lua source <afile> | PackerCompile]]}, true)
-- autocmd('packer_user_config', {[[BufWritePost init.lua source <afile> | PackerCompile]]}, true)

-- Disable some built-in plugins we don't want
local disabled_built_ins = {'gzip', 'man', 'matchit', 'matchparen', 'shada_plugin', 'tarPlugin', 'tar', 'zipPlugin',
                            'zip' -- 'netrwPlugin',
}
for i = 1, #disabled_built_ins do
    g['loaded_' .. disabled_built_ins[i]] = 1
end

-- build-in plugins settings
-- netrw
-- g.netrw_banner = 1
-- g.netrw_browse_split = 4
-- g.netrw_altv = 1
g.netrw_liststyle = 3
-- g.netrw_winsize = 25
map('n', '<C-n>', '<cmd>Vexplore<cr>')

-- statusline
vim.cmd [[
  au VimEnter * ++once lua statusline = require('statusline')
  au VimEnter * ++once lua vim.o.statusline = '%!v:lua.statusline.status()'
]]

-- functions
function helptab()
    if vim.o.buftype == 'help' then
        vim.cmd([[wincmd T]])
        vim.api.nvim_buf_set_keymap('0', 'n', 'q', '<cmd>q<cr>', {
            silent = true,
            noremap = true
        })
    end
end
autocmd('open_help_tab', {[[BufEnter *.txt lua helptab()]]}, true)
-- autocmd('open_help_tab', {[[FileType help lua helptab()]]}, true)

local function map_change_option(...)
    local prefix = 'co'
    local key = select(1, ...)
    local option = select(2, ...)

    vim.api.nvim_set_keymap('n', prefix .. key, ':set ' .. option .. '!<cr>', {})
end

map_change_option('w', 'warp')
map_change_option('p', 'paste')
map_change_option('n', 'number')
map_change_option('r', 'relativenumber')
map_change_option('h', 'hlsearch')

autocmd('no_conceallevel', {[[FileType markdown set cole=0]]}, true)
