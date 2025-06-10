local pipe_path = function()
	return vim.env.NVIM
end

local addr = pipe_path()
if not addr then
	return
end

local ok, chan = pcall(vim.fn.sockconnect, "pipe", addr, { rpc = true })
if not ok then
	return
end

local exit_nvim = function()
	vim.cmd("qall!")
end

local rpcnotify = function(chan, fn, args)
	local code = vim.base64.encode(string.dump(fn, true))
	vim.fn.rpcnotify(
		chan,
		"nvim_exec_lua",
		string.format(
			[[
      return loadstring(vim.base64.decode('%s'))(...)
    ]],
			code
		),
		args
	)
end
local files = vim.fn.argv() or {}
local full_paths = {}
for _, file in ipairs(files) do
	local file = vim.fs.abspath(file)
	table.insert(full_paths, file)
end
if #files > 0 then
	rpcnotify(chan, function(...)
		local args = { ... }
		-- botright split
		-- topleft split
		vim.cmd("botright split " .. args[1])
	end, full_paths)
	exit_nvim()
end

vim.api.nvim_create_autocmd("StdinReadPost", {
	pattern = "*",
	callback = function()
		local readlines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
		rpcnotify(chan, function(...)
			local args = { ... }
			vim.cmd("botright new")
			vim.api.nvim_buf_set_lines(0, 0, -1, false, args)
		end, readlines)
		exit_nvim()
	end,
})
