-- Run from the repository root: nvim --headless -u NONE -i NONE -l xdg_config/nvim/tests/mini-files-bookmarks.lua
local temporary = vim.fn.tempname()
vim.fn.mkdir(temporary .. "/config", "p")
temporary = assert(vim.uv.fs_realpath(temporary))
local original_stdpath = vim.fn.stdpath
vim.fn.stdpath = function(kind)
	if kind == "state" or kind == "config" then
		return temporary .. "/" .. kind
	end
	return original_stdpath(kind)
end
local plugin = vim.fn.globpath(original_stdpath("data") .. "/site/pack", "*/opt/mini.nvim", false, true)[1]
assert(plugin, "Install mini.nvim before running this test")
vim.opt.runtimepath:append(plugin)

local source = table.concat(vim.fn.readfile("xdg_config/nvim/lua/liu/pack.lua"), "\n")
local first = assert(source:find('nvim_on("VimEnter", aug_mini, function()\n\tlocal aug_mini_files', 1, true))
local last = assert(source:find('-- vim.pack.add({ "https://github.com/nvim-mini/mini.bufremove" })', first, true))
local env = setmetatable({
	nvim_on = function(_, _, callback)
		callback()
	end,
}, { __index = _G })
setfenv(assert(loadstring(source:sub(first, last - 1))), env)()
local MiniFiles = require("mini.files")
local a, b, shared = temporary .. "/alpha", temporary .. "/beta", temporary .. "/shared"
for _, path in ipairs({ a, b, shared, a .. "/src", a .. "/test" }) do
	vim.fn.mkdir(path, "p")
end
local function read(root)
	local path = temporary .. "/state/mini-files-bookmarks/" .. vim.fn.sha256(root) .. ".json"
	return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
end

local function run()
	local tab1 = vim.api.nvim_get_current_tabpage()
	vim.cmd("tcd " .. a)
	MiniFiles.open(a .. "/src")
	vim.cmd("tabnew")
	local tab2 = vim.api.nvim_get_current_tabpage()
	vim.cmd("tcd " .. a)
	MiniFiles.open(a .. "/test")
	vim.api.nvim_set_current_tabpage(tab1)
	MiniFiles.set_bookmark("A", a .. "/src")
	assert(MiniFiles.close())
	vim.api.nvim_set_current_tabpage(tab2)
	MiniFiles.set_bookmark("B", a .. "/test")
	assert(MiniFiles.close())
	assert(read(a).A and read(a).A.path == a .. "/src", "Another explorer lost bookmark A")
	assert(read(a).B.path == a .. "/test")

	-- A stale, unchanged bookmark must not override a newer edit of the same id.
	vim.api.nvim_set_current_tabpage(tab1)
	MiniFiles.open(a .. "/src")
	vim.api.nvim_set_current_tabpage(tab2)
	MiniFiles.open(a .. "/test")
	vim.api.nvim_set_current_tabpage(tab1)
	MiniFiles.set_bookmark("A", a .. "/test")
	assert(MiniFiles.close())
	vim.api.nvim_set_current_tabpage(tab2)
	MiniFiles.set_bookmark("D", a)
	assert(MiniFiles.close())
	assert(read(a).A.path == a .. "/test", "An unchanged stale bookmark overwrote a newer edit")
	assert(read(a).D.path == a)
	vim.api.nvim_set_current_tabpage(tab1)
	MiniFiles.open(a .. "/src")
	vim.api.nvim_set_current_tabpage(tab2)
	MiniFiles.open(a .. "/test")
	MiniFiles.set_bookmark("D", a .. "/test")
	vim.api.nvim_set_current_tabpage(tab1)
	MiniFiles.set_bookmark("D", a .. "/src")
	assert(MiniFiles.close())
	vim.api.nvim_set_current_tabpage(tab2)
	assert(MiniFiles.close())
	assert(read(a).D.path == a .. "/test", "The last local edit to close must win")

	-- The project's history must follow close order, not open order.
	vim.api.nvim_set_current_tabpage(tab1)
	MiniFiles.open(shared)
	assert(MiniFiles.close())
	vim.api.nvim_set_current_tabpage(tab2)
	vim.cmd("tcd " .. b)
	MiniFiles.open(shared)
	MiniFiles.set_bookmark("Z", b)
	-- Resetting an explorer must not erase attribution of the still-cached history.
	vim.cmd("tabnew")
	local c = temporary .. "/gamma"
	vim.fn.mkdir(c, "p")
	vim.cmd("tcd " .. c)
	MiniFiles.open(shared)
	assert(MiniFiles.get_explorer_state().bookmarks.A == nil, "Cached history leaked into a third project")
	assert(MiniFiles.close())
	vim.api.nvim_set_current_tabpage(tab1)
	MiniFiles.open(shared)
	assert(MiniFiles.close())
	vim.api.nvim_set_current_tabpage(tab2)
	assert(MiniFiles.close())
	vim.api.nvim_set_current_tabpage(tab1)
	MiniFiles.open(shared)
	assert(MiniFiles.get_explorer_state().bookmarks.Z == nil, "Project beta's bookmark leaked into alpha")
	assert(MiniFiles.close())
	assert(read(a).Z == nil, "A foreign bookmark was persisted")
	assert(read(b).Z.path == b)

	MiniFiles.open(a, false)
	assert(MiniFiles.get_explorer_state().bookmarks.A.path == a .. "/test")
	vim.api.nvim_feedkeys("`A", "xt", false)
	local state = MiniFiles.get_explorer_state()
	assert(state.branch[state.depth_focus] == a .. "/test")
	MiniFiles.set_bookmark("a", a)
	MiniFiles.set_bookmark("F", function()
		return a
	end)
	MiniFiles.set_bookmark("M", a)
	vim.cmd("tcd " .. b)
	assert(MiniFiles.close())
	assert(read(a).M.path == a, "Changing cwd changed the save destination")
	assert(read(a).a == nil and read(a).C == nil and read(a).F == nil)
	assert(read(b).M == nil)

	local path = temporary .. "/state/mini-files-bookmarks/" .. vim.fn.sha256(b) .. ".json"
	vim.fn.writefile({ vim.json.encode({ Y = { path = temporary .. "/missing" } }) }, path)
	MiniFiles.open(b, false)
	assert(MiniFiles.get_explorer_state().bookmarks.Y == nil)
	assert(MiniFiles.close())
	vim.fn.writefile({ "invalid-json" }, path)
	MiniFiles.open(b, false)
	MiniFiles.set_bookmark("N", b)
	assert(MiniFiles.close())
	assert(vim.fn.readfile(path)[1] == "invalid-json", "Corrupt bookmarks were overwritten")
end

local ok, err = xpcall(run, debug.traceback)
vim.fn.stdpath = original_stdpath
vim.fn.delete(temporary, "rf")
if not ok then
	error(err)
end
print("PASS: concurrent bookmarks, stale snapshots, and cross-project history")
