vim.o.mouse = ""
vim.o.clipboard = "unnamedplus"

-- execute .nvim.lua, .nvimrc, and .exrc files
-- in the current directory.
vim.o.exrc = true

-- =============================================================================
-- UI
-- =============================================================================
vim.o.termguicolors = true

vim.o.title = true
vim.o.titlestring = vim.iter({
	[[%{exists('$SSH_TTY')?' <'.hostname().'>':''}]],
	[[%{v:progname}]],
	-- [[%{tolower(empty(v:servername)?'':'--servername '.v:servername.' ')}]],
	[[%{fnamemodify(getcwd(),':~')}]],
}):join(" ")

vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = "yes"

vim.o.laststatus = 3

vim.o.cursorline = true

vim.o.pumheight = 12

vim.o.winborder = "single"

vim.o.guicursor = vim.iter({
	-- "a:block",
	"n-v:block",
	"o:hor50",
	"c:ver25",
	"i-ci-c:ver25",
	"r-cr:hor20",
	"t:ver25",
	"a:blinkwait700-blinkoff400-blinkon250-Cursor",
}):join(",")

-- =============================================================================
-- Folding
-- =============================================================================
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldtext = ""
-- treesitter foldexpr as default
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"

-- =============================================================================
-- Search and Replace
-- =============================================================================
vim.o.ignorecase = true -- search case insensitive
vim.o.smartcase = true -- search matters if capital letter
-- vim.o.inccommand = "split"

-- =============================================================================
-- Time
-- =============================================================================
-- vim.o.timeout = true
vim.o.timeoutlen = 300
vim.o.updatetime = 3000

-- =============================================================================
-- tab, window, buffer
-- =============================================================================
vim.o.tabclose = "uselast"
--
vim.o.splitright = true
-- vim.o.splitbelow = false
--
-- SEE: https://github.com/neovim/neovim/pull/19243
vim.o.splitkeep = "screen"
-- Controls the behavior when switching between buffers
vim.o.switchbuf = "useopen,uselast"

-- =============================================================================
-- Wrap
-- =============================================================================
vim.o.wrap = false
vim.o.whichwrap = "b,s,<,>,h,l"

-- =============================================================================
-- complete stuff
-- =============================================================================
vim.cmd([[
set completeopt=menuone,noselect,fuzzy

set wildmode=longest:full,full
set wildignore+=.git,*.o
set wildoptions+=fuzzy
]])

-- =============================================================================
-- Tabbing
-- =============================================================================
vim.o.expandtab = true
vim.o.tabstop = 4

-- =============================================================================
-- Bracket match
-- =============================================================================
vim.o.showmatch = true
vim.o.matchtime = 3
vim.o.matchpairs = vim.iter({
	vim.o.matchpairs,
	"<:>",
}):join(",")

-- =============================================================================
-- Path stuff
-- =============================================================================
vim.cmd([[
" DWIM 'includeexpr': make gf work on filenames like "a/…" (in diffs, etc.).
set includeexpr=substitute(v:fname,'^[^\/]*/','','')
]])

-- jumplist
-- vim.o.jumpoptions = "stack" -- stack or view
vim.cmd([[
set jumpoptions+=stack
]])

-- string-like-this to be treated as word
vim.opt.iskeyword:append("-")

-- =============================================================================
-- Nvim status persitent
-- =============================================================================
vim.o.swapfile = false
vim.o.undofile = true
vim.o.undodir = vim.fn.stdpath("data") .. "/undo"
vim.o.shada = vim.iter({
	"r/tmp/",
	"rfugitive:",
	"rterm:",
	"rhealth:",
	vim.o.shada,
}):join(",")

-- Disable providers we do not care a about
vim.g.loaded_ruby_provider = 0 -- disable ruby support
vim.g.loaded_perl_provider = 0 -- disable perl support
vim.g.loaded_node_provider = 0 -- disable nodejs support
vim.g.loaded_python_provider = 0 -- disable python2 support
vim.g.loaded_python3_provider = 0 -- disable python3 support
-- buildin plugins
vim.g.loaded_netrwPlugin = 1 -- disable netrw
vim.g.did_install_default_menus = 1 -- avoid stupid menu.vim (saves ~100ms)
-- Language specified
-- vim.g.rst_fold_enabled = 1
-- vim.g.markdown_folding = 1

if not vim.env.TMUX and not vim.g.clipboard then
	vim.g.clipboard = {
		name = "OSC 52",
		copy = {
			["+"] = require("vim.ui.clipboard.osc52").copy("+"),
			["*"] = require("vim.ui.clipboard.osc52").copy("*"),
		},
		paste = {
			["+"] = require("vim.ui.clipboard.osc52").paste("+"),
			["*"] = require("vim.ui.clipboard.osc52").paste("*"),
		},
	}
end
vim.o.modelineexpr = true
