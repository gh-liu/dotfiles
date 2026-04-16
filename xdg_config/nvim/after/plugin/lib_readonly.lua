---@param cmd string[]
---@param parse fun(stdout: string): string
---@return fun(): string
local function cached_stdlib(cmd, parse)
	local result
	return function()
		if not result then
			local obj = vim.system(cmd, { text = true }):wait()
			result = parse(obj.stdout)
		end
		return result
	end
end

local ft_lib_pattern_fns = {
	rust = cached_stdlib({ "rustc", "--print", "sysroot" }, function(s)
		return vim.trim(s) .. "/lib/rustlib/src/rust*rs"
	end),
	zig = cached_stdlib({ "zig", "env" }, function(s)
		return s:match([[%.std_dir = "([^"]+)"]]) .. "*zig"
	end),
	go = cached_stdlib({ "go", "env", "GOROOT" }, function(s)
		return vim.trim(s) .. "/src*go"
	end),
	python = function()
		local root = vim.fs.root(0, { ".venv" })
		if root then
			return root .. "/.venv/lib*"
		end
		return false
	end,
}

local g = vim.api.nvim_create_augroup("liu/lib_readonly", { clear = true })
for lang, lib_pattern_fn in pairs(ft_lib_pattern_fns) do
	vim.api.nvim_create_autocmd("FileType", {
		pattern = lang,
		callback = function(env)
			local pattern = lib_pattern_fn()
			if pattern then
				vim.api.nvim_create_autocmd("BufRead", {
					group = g,
					pattern = pattern,
					command = "setlocal readonly | setlocal nomodifiable",
				})
				local bufname = vim.api.nvim_buf_get_name(env.buf)
				if bufname ~= "" and vim.fn.matchstr(bufname, vim.fn.glob2regpat(pattern)) ~= "" then
					vim.bo[env.buf].readonly = true
					vim.bo[env.buf].modifiable = false
				end
			end
		end,
		once = true,
	})
end
