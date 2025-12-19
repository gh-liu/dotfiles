-- global -> tabpage -> window
-- see chdir()
local getcwds = function()
	return {
		window = vim.fn.getcwd(0, 0),
		tabpage = vim.fn.getcwd(-1, 0),
		global = vim.fn.getcwd(-1, -1),
	}
end

local auto_root_dirs = {
	{
		".git",
		-- "Makefile",
		-- "go.mod", -- go
		-- "Cargo.toml", -- rust
		-- "build.zig.zon", -- zig
		-- "pyproject.toml", -- python
		".nvimrc", -- :h exrc
		".nvim.lua", -- :h exrc
		".projections.json", -- :h projectionist-setup
	}, -- make those dirs same priority
}

vim.o.autochdir = false
vim.api.nvim_create_autocmd({
	-- "SessionLoadPost",
	"VimEnter",
}, {
	group = vim.api.nvim_create_augroup("setup_auto_root", {}),
	callback = function(_data)
		if vim.fn.empty(vim.v.this_session) == 0 then
			return
		end

		local buf = vim.api.nvim_get_current_buf()
		if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
			return
		end

		local root = vim.fs.root(buf, auto_root_dirs)
		if root == nil or root == vim.fn.getcwd(-1, 0) then
			return
		end
		-- vim.print(getcwds())
		vim.fn.chdir(root, "tabpage")
		vim.api.nvim_echo({ { "chdir to " .. root, "WarningMsg" } }, true, {})
		-- vim.print(getcwds())
	end,
	desc = "Find root and change current directory",
	once = true,
})
