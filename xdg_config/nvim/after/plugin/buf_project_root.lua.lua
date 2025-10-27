local auto_root_dirs = {
	".git",
	-- "Makefile",
	-- "go.mod", -- go
	-- "Cargo.toml", -- rust
	-- "build.zig.zon", -- zig
	-- "pyproject.toml", -- python
	".nvimrc", -- :h exrc
	".nvim.lua", -- :h exrc
	".projections.json", -- :h projectionist-setup
}
if vim.fn.has("nvim-0.11.3") == 1 then
	auto_root_dirs = { auto_root_dirs }
end

vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("setup_auto_root", {}),
	callback = function(data)
		-- vim.o.autochdir = false
		local root = vim.fs.root(data.buf, auto_root_dirs)
		if root == nil or root == vim.fn.getcwd() then
			return
		end
		vim.fn.chdir(root)
		vim.api.nvim_echo({ { "chdir to " .. root, "WarningMsg" } }, true, {})
	end,
	desc = "Find root and change current directory",
	once = true,
})
