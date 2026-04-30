-- global -> tabpage -> window
-- see chdir()
local getcwds = function()
	return {
		window = vim.fn.getcwd(0, 0),
		tabpage = vim.fn.getcwd(-1, 0),
		global = vim.fn.getcwd(-1, -1),
	}
end

vim.o.autochdir = false

local buf_root_dir = function(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return
	end
	local buf_root_dirs = {
		vim.b[buf].buf_root_dirs or {
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
	return vim.fs.root(buf, buf_root_dirs)
end

local chdir2root = function(root)
	vim.fn.chdir(root, "tabpage")
	vim.api.nvim_echo({ { "chdir to " .. root, "WarningMsg" } }, true, {})
end

vim.keymap.set("n", "cD", function()
	local root = buf_root_dir()
	if root then
		chdir2root(root)
	end
end, {})

-- TODO: auto setup root from lsp, use LspAttach event
vim.api.nvim_create_autocmd({
	-- "SessionLoadPost",
	"VimEnter",
}, {
	group = vim.api.nvim_create_augroup("setup_auto_root", {}),
	callback = function(_data)
		if vim.fn.empty(vim.v.this_session) == 0 then
			return
		end

		local root = buf_root_dir(vim.api.nvim_get_current_buf())
		if root == nil or root == vim.fn.getcwd(-1, 0) then
			return
		end
		-- vim.print(getcwds())
		chdir2root(root)
		-- vim.print(getcwds())
	end,
	desc = "Find root and change current directory",
	once = true,
})
