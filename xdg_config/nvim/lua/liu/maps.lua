local setmap = function(mode, lhs, rhs, opts)
	opts = opts or { silent = true }
	vim.keymap.set(mode, lhs, rhs, opts)
end

local function toggle_opt(op, option, val)
	if not val then
		return setmap("n", ("co" .. op), (":set " .. option .. "!" .. "<bar> set " .. option .. "?<cr>"))
	else
		local vv = val
		return setmap("n", "co" .. op, function()
			vim.o[option], vv = vv, vim.o[option]
			vim.cmd(string.format("set %s?", option))
		end)
	end
end

toggle_opt("w", "wrap")
toggle_opt("p", "paste")
toggle_opt("f", "fen")
toggle_opt("h", "hlsearch")
toggle_opt("c", "cursorcolumn")
toggle_opt("C", "cursorbind")
toggle_opt("S", "scrollbind")
toggle_opt("m", "mouse", "a")
toggle_opt("t", "laststatus", 0)
-- toggle_opt("i", "smartcase")
-- toggle_opt("n", "number")
-- toggle_opt("r", "relativenumber")
-- toggle_opt("s", "wrapscan")

local function rtf(keys, mode)
	local tkeys = vim.api.nvim_replace_termcodes(keys, true, true, true)
	return function()
		return vim.api.nvim_feedkeys(tkeys, mode, false)
	end
end

setmap("c", "<C-h>", rtf("<left>", "c"))
setmap("c", "<C-j>", rtf("<down>", "c"))
setmap("c", "<C-k>", rtf("<up>", "c"))
setmap("c", "<C-l>", rtf("<right>", "c"))
setmap("c", "<C-a>", rtf("<HOME>", "c"))
setmap("c", "<C-e>", rtf("<END>", "c"))

setmap("i", "<C-a>", "<HOME>")
setmap("i", "<C-e>", "<END>")

-- Remap for dealing with word wrap
setmap({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
setmap({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

setmap("i", "jj", "<Esc>")
setmap("i", "kk", "<Esc>")
setmap("i", "<C-c>", "<Esc>")

setmap("x", "<", "<gv")
setmap("x", ">", ">gv")
setmap("x", "K", ":move '<-2<CR>gv=gv")
setmap("x", "J", ":move '>+1<CR>gv=gv")

setmap("n", "Y", "y$")
setmap("x", "Y", "<ESC>y$gv")

setmap("n", "n", "nzzzv")
setmap("n", "N", "Nzzzv")
setmap("n", "*", "#zz")
setmap("n", "#", "*zz")
setmap("n", "<C-d>", "<C-d>zz")
setmap("n", "<C-u>", "<C-u>zz")

setmap("n", "[b", ":bprev<cr>")
setmap("n", "]b", ":bnext<cr>")

setmap("n", "<leader>cc", "<cmd>try | cclose | lclose | tabclose | catch | endtry <cr>")
setmap("n", "[q", "<cmd>try | cprev | catch | silent! clast | catch | endtry<cr>zv")
setmap("n", "]q", "<cmd>try | cnext | catch | silent! cfirst | catch | endtry<cr>zv")
setmap("n", "<leader>k", "<cmd>try | cprev | catch | silent! clast | catch | endtry<cr>zv")
setmap("n", "<leader>j", "<cmd>try | cnext | catch | silent! cfirst | catch | endtry<cr>zv")
setmap("n", "[l", ":lprev<cr>")
setmap("n", "]l", ":lnext<cr>")

setmap("n", "<C-q>", ":quit<CR>")

setmap("n", "<C-w>O", ":tabonly<CR>")

-- HJKL as amplified versions of hjkl
setmap({ "n", "x", "o" }, "H", "^")
setmap({ "n", "x", "o" }, "L", "$")
-- setmap("n", "J", "6j")
-- setmap("n", "K", "6k")

-- keep the old word in the clipboard
setmap("x", "p", '"_dP')

-- changing a word
setmap("n", "cn", "*``cgn")

-- search for selection
setmap("x", "//", [[y/<c-r>=trim(escape(@",'\/]'))<cr><cr>]])

setmap("n", "<leader>A", "ggVG")

-- for i = 65, 90 do -- A-Z
for i = 97, 122 do -- a-z
	local mark = string.char(i)
	local l = string.format("dm%s", mark)
	local r = string.format(":delm %s<CR>", mark)
	setmap("n", l, r)
end
setmap("n", "M", "g'")

vim.cmd([[
smap <BS> <BS>i
]])

-- toggle folds
-- setmap(
-- 	"n",
-- 	"<space>",
-- 	"@=(foldlevel('.')?'za':'<space>')<cr>",
-- 	{ silent = true, desc = "Fold Toggle", expr = false }
-- )

-- -- fixing that stupid typo when trying to [save]exit
-- vim.cmd([[
--     cnoreabbrev <expr> W     ((getcmdtype()  is# ':' && getcmdline() is# 'W')?('w'):('W'))
--     cnoreabbrev <expr> Q     ((getcmdtype()  is# ':' && getcmdline() is# 'Q')?('q'):('Q'))
-- ]])
local opts = {
	expr = true,
	desc = "fixing that stupid typo when trying to [save]exit",
	noremap = true,
}
local desc = "fixing that stupid typo when trying to [save]exit"
setmap("ca", "W", "((getcmdtype()  is# ':' && getcmdline() is# 'W')?('w'):('W'))", opts)
setmap("ca", "Q", "((getcmdtype()  is# ':' && getcmdline() is# 'Q')?('q'):('Q'))", opts)
