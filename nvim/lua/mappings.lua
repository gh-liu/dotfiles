local map = require("utils").map

-- Keybingdings
local silent = {
	silent = true,
}

local silent_noremap = {
	silent = true,
	noremap = true,
}

-- disable F1
map("", "<F1>", "<Esc>")

-- Switch ` and '
map("n", "'", "`")
map("n", "'", "`")

-- display lines move up or down
map("n", "j", "gj")
map("n", "k", "gk")

-- windows moving
map("n", "<C-h>", "<C-w>h", silent)
map("n", "<C-j>", "<C-w>j", silent)
map("n", "<C-k>", "<C-w>k", silent)
map("n", "<C-l>", "<C-w>l", silent)

-- moving in insert mode
map("i", "<C-h>", "<left>", silent_noremap)
map("i", "<C-j>", "<down>", silent_noremap)
map("i", "<C-k>", "<up>", silent_noremap)
map("i", "<C-l>", "<right>", silent_noremap)
map("i", "<C-a>", "<HOME>", silent_noremap)
map("i", "<C-e>", "<END>", silent_noremap)

map("n", "[w", "<cmd>tabprevious<cr>")
map("n", "]w", "<cmd>tabnext<cr>")
map("n", "[W", "<cmd>tabfirst<cr>")
map("n", "]W", "<cmd>tablast<cr>")

-- map('n', '[b', '<cmd>bprevious<cr>')
-- map('n', ']b', '<cmd>bnext<cr>')
-- map('n', '[B', '<cmd>bfirst<cr>')
-- map('n', ']B', '<cmd>blast<cr>')

map("n", "[l", "<cmd>lprevious<cr>")
map("n", "]l", "<cmd>lnext<cr>")
map("n", "[L", "<cmd>lfirst<cr>")
map("n", "]L", "<cmd>llast<cr>")

map("n", "[q", "<cmd>cprevious<cr>")
map("n", "]q", "<cmd>cnext<cr>")
map("n", "[Q", "<cmd>cfirst<cr>")
map("n", "]Q", "<cmd>clast<cr>")

-- map('n', '[t', '<cmd>tprevious<cr>')
-- map('n', ']t', '<cmd>tnext<cr>')
-- map('n', '[T', '<cmd>tfirst<cr>')
-- map('n', ']T', '<cmd>tlast<cr>')

-- <Leader>[1-9] move to tab [1-9]
for i = 1, 9, 1 do
	map("n", "<leader>" .. i, i .. "gt")
end

map("n", "<c-a>", "<c-o>")

-- Do not show stupid q: window
map("n", "q:", ":q")

-- qq to record, Q to replay
map("n", "Q", "@q")

-- same as D
map("n", "Y", "y$")

-- Don't lose selection when shifting sidewards
map("x", "<", "<gv")
map("x", ">", ">gv")

-- Change window size
map("n", "<left>", "<c-w>>", silent)
map("n", "<right>", "<c-w><", silent)
map("n", "<up>", "<c-w>-", silent)
map("n", "<down>", "<c-w>+", silent)

-- Keep search pattern at the center of the screen
map("n", "n", "nzz", silent)
map("n", "N", "Nzz", silent)

-- Switch # *
map("n", "*", "#zz", silent)
map("n", "#", "*zz", silent)

-- moving in cmd-line mode
map("c", "<C-h>", "<left>")
map("c", "<C-j>", "<down>")
map("c", "<C-k>", "<up>")
map("c", "<C-l>", "<right>")
-- map('c', '<C-a>', '<HOME>')
-- map('c', '<C-e>', '<END>')

-- move to head or end of line in normal or visual mode
map("n", "H", "^")
map("n", "L", "$")
map("v", "H", "^")
map("v", "L", "g_")

-- Edit alternate file
map("i", "<C-^>", "<C-o><C-^>")

-- Save
map("i", "<C-s>", "<C-O>:update<cr>")
map("n", "<C-s>", ":update<cr>")

-- Exit
map("i", "<C-q>", "<esc>:q<cr>")
map("n", "<C-q>", ":q<cr>")
map("v", "<C-q>", "<esc>")
map("n", "<Leader>q", ":q<cr>")
map("n", "<Leader>Q", ":qa!<cr>")

-- <Leader>c Close quickfix/location window
map("n", "<leader>c", ":cclose<bar>lclose<cr>", silent)

-- Edit $MYVIMRC
map("n", "<leader>ev", ":tabnew $MYVIMRC<cr>", silent)

map("i", "jj", "<Esc>")
map("i", "kk", "<Esc>")

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
