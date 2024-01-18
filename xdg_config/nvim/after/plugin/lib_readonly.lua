if false then
	return
end

local api = vim.api
local fn = vim.fn
local json = vim.json

local lib_patterns = {}

if fn.executable("zig") == 1 then
	local zig_envs = json.decode(fn.system({ "zig", "env" }))
	local lib_dir = zig_envs.lib_dir .. "/**.zig"
	table.insert(lib_patterns, lib_dir)
end

if fn.executable("rustc") == 1 then
	local rust_sysroot = vim.system({ "rustc", "--print", "sysroot" }, { text = true }):wait(1000).stdout
	rust_sysroot = rust_sysroot:sub(1, #rust_sysroot - 1)
	-- local rust_sysroot = fn.system({ "rustc", "--print", "sysroot" })
	local lib_dir = rust_sysroot .. "/lib/**.rs"
	table.insert(lib_patterns, lib_dir)
end

if fn.executable("go") == 1 then
	local go_root = vim.system({ "go", "env", "GOROOT" }, { text = true }):wait(1000).stdout
	go_root = go_root:sub(1, #go_root - 1)
	-- local go_root = fn.system({ "go", "env", "GOROOT" })
	local lib_dir = go_root .. "/src/**.go"
	table.insert(lib_patterns, lib_dir)
end

if #lib_patterns > 0 then
	api.nvim_create_autocmd("BufReadPre", {
		group = api.nvim_create_augroup("liu/libs_readonly", { clear = true }),
		pattern = lib_patterns,
		callback = function(ev)
			api.nvim_set_option_value("readonly", true, { buf = ev.buf })
			api.nvim_set_option_value("modifiable", false, { buf = ev.buf })
		end,
	})
end
