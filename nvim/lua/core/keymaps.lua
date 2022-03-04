local map = as.map

-- Basics {{{1
--
-- Disable F1
map("", "<F1>", "<Esc>")
-- Switch ` and '
map("n", "'", "`")
map("n", "'", "`")

-- <Leader>[1-9] move to tab [1-9]
for i = 1, 9, 1 do
	map("n", "<leader>" .. i, i .. "gt")
end
-- Select tab
map("n", "[w", "<cmd>tabprevious<cr>")
map("n", "]w", "<cmd>tabnext<cr>")
map("n", "[W", "<cmd>tabfirst<cr>")
map("n", "]W", "<cmd>tablast<cr>")
-- Select buffer
-- map('n', '[b', '<cmd>bprevious<cr>')
-- map('n', ']b', '<cmd>bnext<cr>')
-- map('n', '[B', '<cmd>bfirst<cr>')
-- map('n', ']B', '<cmd>blast<cr>')
-- Select window
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- Display lines move up or down
map("n", "j", "gj")
map("n", "k", "gk")
-- Moving in insert mode
map("i", "<C-h>", "<left>")
map("i", "<C-j>", "<down>")
map("i", "<C-k>", "<up>")
map("i", "<C-l>", "<right>")
map("i", "<C-a>", "<HOME>")
map("i", "<C-e>", "<END>")
-- Move to head or end of line in normal or visual mode
map("n", "H", "^")
map("n", "L", "$")
map("v", "H", "^")
map("v", "L", "g_")
-- Moving in cmd-line mode
vim.cmd([[
  cnoremap     <C-h> <left>
  cnoremap     <C-j> <down>
  cnoremap     <C-k> <up>
  cnoremap     <C-l> <right>
]])
-- Move selected line / block of text in visual mode
as.map("x", "K", ":move '<-2<CR>gv=gv")
as.map("x", "J", ":move '>+1<CR>gv=gv")
-- Automatically jump to the end of pasted text
as.map("v", "y", "y`]")
as.map("v", "p", "p`]")
as.map("n", "p", "p`]")

-- select locallist item
map("n", "[l", "<cmd>lprevious<cr>")
map("n", "]l", "<cmd>lnext<cr>")
map("n", "[L", "<cmd>lfirst<cr>")
map("n", "]L", "<cmd>llast<cr>")
-- select quickfix item
map("n", "[q", "<cmd>cprevious<cr>")
map("n", "]q", "<cmd>cnext<cr>")
map("n", "[Q", "<cmd>cfirst<cr>")
map("n", "]Q", "<cmd>clast<cr>")

-- Keep search pattern at the center of the screen
map("n", "n", "nzz")
map("n", "N", "Nzz")
-- Switch # *
map("n", "*", "#zz")
map("n", "#", "*zz")

-- jj/kk exit insert mode
map("i", "jj", "<Esc>")
map("i", "kk", "<Esc>")

-- Do not show stupid q: window
map("n", "q:", ":q")

-- Exit
map("n", "<C-q>", ":call v:lua.smartquit()<cr>")
map("i", "<C-q>", "<esc>:q<cr>")
map("v", "<C-q>", "<esc>")
map("n", "<Leader>q", ":q<cr>")
map("n", "<Leader>Q", ":qa!<cr>")

-- Save
map("i", "<C-s>", "<C-O>:update<cr>")
map("n", "<C-s>", ":update<cr>")

-- qq to record, Q to replay
map("n", "Q", "@q")

-- same as D
map("n", "Y", "y$")
map("v", "Y", "<ESC>y$gv")

-- jump
map("n", "<c-a>", "<c-o>")

-- Don't lose selection when shifting sidewards
map("x", "<", "<gv")
map("x", ">", ">gv")

-- Change window size
-- map("n", "<left>", "<c-w>>")
-- map("n", "<right>", "<c-w><")
-- map("n", "<up>", "<c-w>-")
-- map("n", "<down>", "<c-w>+")

-- Edit alternate file
map("i", "<C-^>", "<C-o><C-^>")

-- <Leader>c Close quickfix/location window
map("n", "<leader>c", ":cclose<bar>lclose<cr>")

-- Edit $MYVIMRC
map("n", "<leader>ev", ":tabnew $MYVIMRC<cr>")

-- fold
vim.cmd([[ nnoremap <silent> <space> @=(foldlevel('.')?'za':"\<space>")<cr> ]])

local function map_change_option(...)
	local prefix = "co"
	local key = select(1, ...)
	local opt = select(2, ...)
	local op = ":set " .. opt .. "!" .. " <bar> set " .. opt .. "?<cr>"
	vim.api.nvim_set_keymap("n", prefix .. key, op, {})
end

map_change_option("w", "warp")
map_change_option("p", "paste")
map_change_option("n", "number")
map_change_option("r", "relativenumber")
map_change_option("h", "hlsearch")

function _G.smartquit()
	local buf_nums = vim.fn.len(vim.fn.getbufinfo({ buflisted = 1 }))

	if buf_nums == 1 then
		local ok = pcall(vim.cmd, ":silent quit")
		if not ok then
			local choice = vim.fn.input("E37: Discard changes?  Y|y = Yes, N|n = No, W|w = Write and quit: ")
			if choice == "y" then
				vim.cmd("quit!")
			elseif choice == "w" then
				vim.cmd("write")
				vim.cmd("quit")
			else
				vim.fn.feedkeys("\\<ESC>")
			end
		end
	else
		local ok = pcall(vim.cmd, "bw")

		if not ok then
			local choice = vim.fn.input("E37: Discard changes?  Y|y = Yes, N|n = No, W|w = Write and quit: ")
			if choice == "y" then
				vim.cmd("bw!")
			elseif choice == "w" then
				vim.cmd("write")
				vim.cmd("bw")
			else
				vim.fn.feedkeys("\\<ESC>")
			end
		end
	end
end
