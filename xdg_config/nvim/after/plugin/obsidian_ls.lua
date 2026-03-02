local function obsidian_exec(cmd, args, callback)
	local clients = vim.lsp.get_clients({ name = "obsidian_ls" })
	if #clients == 0 then
		vim.notify("obsidian-lsp not attached", vim.log.levels.WARN)
		return
	end
	local client = clients[1]
	local command = { command = cmd, arguments = args or {} }
	client:exec_cmd(command, nil, function(err, result)
		if err then
			vim.notify("obsidian: " .. (err.message or tostring(err)), vim.log.levels.ERROR)
			return
		end
		if callback then
			callback(result)
		end
	end)
end

local edit_uri = function(uri)
	local fname = vim.uri_to_fname(uri)
	vim.cmd("edit " .. vim.fn.fnameescape(fname))
end

vim.api.nvim_create_user_command("ObsidianNew", function(opts)
	local path = opts.args ~= "" and opts.args or nil
	obsidian_exec("obsidian.new", path and { path } or {}, function(result)
		if result and result.uri then
			edit_uri(result.uri)
		end
	end)
end, { nargs = "?", desc = "Create new note with default template" })

vim.api.nvim_create_user_command("ObsidianNewFromTemplate", function(opts)
	local template = opts.fargs[1]
	local path = opts.fargs[2]
	if not template or template == "" then
		template = vim.fn.input("Template name: ")
	end
	if template == "" then
		vim.notify("Template name required", vim.log.levels.WARN)
		return
	end
	local args = { template }
	if path and path ~= "" then
		table.insert(args, path)
	end
	obsidian_exec("obsidian.newFromTemplate", args, function(result)
		if result and result.uri then
			edit_uri(result.uri)
		end
	end)
end, { nargs = "*", desc = "Create note from template" })
