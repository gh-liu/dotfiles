-- https://github.com/neovim/neovim/pull/34545

-- `fdfind` on Ubuntu (https://github.com/sharkdp/fd#on-ubuntu)
local fd_cmd = vim.fn.executable("fdfind") == 1 and "fdfind" or vim.fn.executable("fd") == 1 and "fd"
if fd_cmd then
	vim.o.findfunc = "v:lua.findfunc"

	function _G.findfunc(cmdarg, cmdcomplete)
		-- convert special 'path' values
		local paths = vim.iter(vim.opt.path:get())
			:map(function(v)
				if v == "." then -- relative to current file
					return "./" .. vim.fn.expand("%:h")
				elseif v == "" or v == "**" then -- relative to 'current-directory'
					return "."
				end
				return v
			end)
			:totable()

		local cmds = {
			fd_cmd,
			-- "--hidden", -- -H, --hidden: Search hidden files and directories
			-- "--no-ignore", -- -I, --no-ignore: Do not respect .(git|fd)ignore files
			"--full-path", -- -p, --full-path: Search full abs. path (default: filename only)
			cmdarg or ".",
		}

		local cmd = vim.list_extend(cmds, paths)
		-- vim.print(vim.iter(cmd):join(" "))
		local result = vim.system(cmd, { text = true }):wait()
		local list = vim.split(result.stdout, "\n", { trimempty = true })
		list = vim.list.unique(list)
		return list
	end
end
