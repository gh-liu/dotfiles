local ft_lib_pattern_fns = {
	zig = function()
		if not vim.env.ZIGSTDLIB then
			local obj = vim.system({ "zig", "env" }, { text = true }):wait()
			local stdout = obj.stdout
			local res = vim.json.decode(stdout, {})
			vim.env.ZIGSTDLIB = res.std_dir
		end
		return vim.env.ZIGSTDLIB .. "*zig"
	end,
	go = function()
		if not vim.env.GOSTDLIB then
			local obj = vim.system({ "go", "env", "GOROOT" }, { text = true }):wait()
			local stdout = obj.stdout
			vim.env.GOSTDLIB = vim.trim(stdout) .. "/src"
		end
		return vim.env.GOSTDLIB .. "*go"
	end,
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
				vim.api.nvim_exec_autocmds("BufRead", { buffer = env.buf, modeline = false })
			end
		end,
		once = true,
	})
end
