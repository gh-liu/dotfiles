vim.o.termguicolors = true

vim.o.mouse = ""

vim.o.hlsearch = false
vim.o.incsearch = true

vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.undofile = true
vim.o.undodir = os.getenv("HOME") .. "/.vim/undodir"

vim.o.updatetime = 200
vim.o.timeout = true
vim.o.timeoutlen = 300

vim.o.pumheight = 12
vim.o.completeopt = "menuone,noselect"

vim.o.wrap = false
vim.o.whichwrap = "b,s,<,>,h,l"

vim.o.cursorline = true

vim.o.scrolloff = 3

vim.o.laststatus = 3

vim.o.splitright = true
vim.o.splitbelow = false

-- vim.o.autowrite = true

vim.wo.number = true
vim.wo.relativenumber = true
vim.wo.signcolumn = "yes"

vim.o.sessionoptions = "buffers,curdir,folds,tabpages,winsize"

-- :help guicursor
vim.cmd([[
	set guicursor=n-v:block,i-c-ci-ve:ver25,r-cr:hor20,o:hor50
	  \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
	  \,sm:block-blinkwait175-blinkoff150-blinkon175
]])
