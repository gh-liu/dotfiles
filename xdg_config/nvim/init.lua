-- Set my colorscheme.
vim.cmd.colorscheme("nord")

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})

	local name = [[lazy]]
	if vim.v.shell_error == 0 then
		vim.cmd([[redraw]])
		print(name .. ": finished installing")
	else
		print(name .. ": fail to install")
	end
end
vim.opt.rtp:prepend(lazypath)

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.env.DOTNVIM = vim.fn.stdpath("config")

require("liu")
