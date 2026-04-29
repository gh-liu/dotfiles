-- https://echasnovski.com/blog/2026-03-13-a-guide-to-vim-pack

--====== git
local aug_fug = vim.api.nvim_create_augroup("liu.fugitive", { clear = true })
vim.pack.add({
	"https://github.com/tpope/vim-fugitive",
	"https://github.com/tpope/vim-rhubarb",
})
vim.keymap.set("n", "g<space>", function()
	local api = vim.api
	for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
		local buf = api.nvim_win_get_buf(win)
		if vim.b[buf].fugitive_type == "index" then
			api.nvim_buf_delete(buf, { force = true })
			return
		end
	end
	vim.cmd.G({ mods = { keepalt = true } })
end, { silent = true, desc = "Toggle fugitive summary" })
vim.api.nvim_create_autocmd("FileType", {
	group = aug_fug,
	pattern = { "git", "fugitive" },
	callback = function()
		vim.wo[0][0].foldmethod = "syntax"
		if vim.b.fugitive_type == "commit" then
			-- fold all files
			vim.wo[0][0].foldlevel = 0
		end
	end,
})
vim.api.nvim_create_autocmd("FileType", {
	group = aug_fug,
	pattern = "fugitive",
	callback = function()
		vim.cmd([[
			nnoremap <buffer> crt :<C-U>Git reset @~<C-R>=v:count1<CR><CR>
			nnoremap <buffer> crT :<C-U>Git reset --hard @~<C-R>=v:count1<CR><CR>

			nnoremap <buffer> cob :<C-U>Git checkout -b<space>
			"nnoremap <buffer> com :<C-U>Git checkout main<CR>
			"nnoremap <buffer> cbu :<C-U>Git branch -u origin/<C-R>=FugitiveHead()<CR><CR>
			"nnoremap <buffer> cpu :Git push --set-upstream origin <C-R>=FugitiveHead()<CR><CR>

			"cargo install git-absorb
			nnoremap <buffer> gaa :<C-U>Git absorb<space>
			nnoremap <buffer> gar :<C-U>Git absorb --and-rebase<space>
		]])
	end,
})
vim.api.nvim_create_autocmd("User", {
	group = aug_fug,
	pattern = { "FugitiveIndex", "FugitiveObject", "FugitiveStageBlob" },
	callback = function()
		vim.wo[0][0].winhighlight = "StatusLine:StatusLineFugitive"
	end,
})
vim.api.nvim_create_autocmd("SessionLoadPost", {
	group = aug_fug,
	callback = function(ev)
		local buf = ev.buf or api.nvim_get_current_buf()
		if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].fugitive_type == "index" then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end,
})

local aug_ug = vim.api.nvim_create_augroup("liu.ug", { clear = true })
vim.pack.add({ "https://github.com/justinmk/vim-ug" })
vim.api.nvim_create_autocmd("VimEnter", {
	group = aug_ug,
	callback = function(ev)
		vim.cmd([[
			" not gitsigns
			nunmap Un
			nunmap UN
			nunmap <c-n>
			nunmap <c-p>

			"nmap Ubb 1Ub
			"nmap UL 9Ul
		]])
	end,
})

local aug_flog = vim.api.nvim_create_augroup("liu.flog", { clear = true })
vim.pack.add({ "https://github.com/rbong/vim-flog" })
vim.g.flog_enable_dynamic_branch_hl = 0
vim.g.flog_use_internal_lua = 1
vim.g.flog_default_opts = { max_count = 2000 }
vim.g.flog_permanent_default_opts = { date = "format:%Y-%m-%d %H:%M" }
vim.keymap.set("ca", "F", "Flogsplit", {})
vim.api.nvim_create_autocmd("FileType", {
	group = aug_flog,
	pattern = "floggraph",
	callback = function(env)
		local buf = env.buf
		vim.keymap.set("n", "crt", "<Cmd>exec flog#Format('Floggit reset %h')<CR>", { buf = buf })
		vim.keymap.set("n", "crT", "<Cmd>exec flog#Format('Floggit reset --hard %h')<CR>", { buf = buf })
	end,
})

vim.pack.add({
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/neogitorg/neogit",
})
