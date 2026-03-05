local M = {}

M.setup = function()
	vim.api.nvim_create_user_command("LspWorkspace", function(opts)
		local subcmd = opts.fargs[1] or "list"

		if subcmd == "add" then
			local path = opts.fargs[2]
			if not path or path == "" then
				vim.notify("LspWorkspace add requires a path", vim.log.levels.WARN)
				return
			end
			local full_path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
			vim.lsp.buf.add_workspace_folder(full_path)
			vim.notify("Added workspace folder: " .. full_path, vim.log.levels.INFO)
			return
		end

		if subcmd == "delete" then
			local path = opts.fargs[2]
			if not path or path == "" then
				vim.notify("LspWorkspace delete requires a path", vim.log.levels.WARN)
				return
			end

			local full_path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
			local folders = vim.lsp.buf.list_workspace_folders()
			local target = path
			for _, folder in ipairs(folders) do
				if vim.fs.normalize(folder) == full_path then
					target = folder
					break
				end
			end
			vim.lsp.buf.remove_workspace_folder(target)
			vim.notify("Removed workspace folder: " .. target, vim.log.levels.INFO)
			return
		end

		local folders = vim.lsp.buf.list_workspace_folders()
		if vim.tbl_isempty(folders) then
			vim.notify("No workspace folders", vim.log.levels.INFO)
			return
		end
		vim.notify(table.concat(folders, "\n"), vim.log.levels.INFO, { title = "LspWorkspace" })
	end, {
		desc = "Manage LSP workspace folders",
		nargs = "*",
		complete = function(arglead, cmdline)
			local args = vim.split(cmdline, "%s+", { trimempty = true })
			local subcmds = { "add", "list", "delete" }
			local trailing_space = cmdline:sub(-1) == " "

			if #args == 1 or (#args == 2 and not trailing_space) then
				return vim.iter(subcmds)
					:filter(function(cmd)
						return vim.startswith(cmd, arglead)
					end)
					:totable()
			end

			local subcmd = args[2]
			if subcmd == "add" then
				return vim.fn.getcompletion(arglead, "dir")
			end

			if subcmd == "delete" then
				return vim.iter(vim.lsp.buf.list_workspace_folders())
					:filter(function(folder)
						return vim.startswith(folder, arglead)
					end)
					:totable()
			end

			return {}
		end,
	})
end

return M
