local CMD = {
	new = "obsidian.new",
	new_from_template = "obsidian.newFromTemplate",
	list_templates = "obsidian.listTemplates",
}

local TemplatePrefix = ":"
local frontmatter = require("liu.utils.frontmatter")

local function get_obsidian_client(bufnr, client_id)
	if client_id then
		local client = vim.lsp.get_client_by_id(client_id)
		if client and client.name == "obsidian_ls" then
			return client
		end
	end

	local clients = vim.lsp.get_clients({ name = "obsidian_ls", bufnr = bufnr })
	if #clients == 0 then
		clients = vim.lsp.get_clients({ name = "obsidian_ls" })
	end
	if #clients == 0 then
		return nil
	end
	return clients[1]
end

local function obsidian_exec(bufnr, cmd, args, callback)
	local client = get_obsidian_client(bufnr)
	if not client then
		vim.notify("obsidian-lsp not attached", vim.log.levels.WARN)
		return
	end
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

local function list_templates(bufnr)
	local command = { command = CMD.list_templates, arguments = {} }
	local result = vim.lsp.buf_request_sync(bufnr, "workspace/executeCommand", command, 1000)
	if not result then
		return {}
	end
	for _, item in pairs(result) do
		if item.result and item.result.templates then
			return item.result.templates
		end
	end
	return {}
end

local edit_uri = function(uri)
	local fname = vim.uri_to_fname(uri)
	vim.cmd("edit " .. vim.fn.fnameescape(fname))
end

vim.api.nvim_create_user_command("ObsidianNew", function(opts)
	local bufnr = vim.api.nvim_get_current_buf()
	local args = opts.fargs
	if #args > 0 and args[1]:match("^" .. TemplatePrefix) then
		local template_name = args[1]:sub(#TemplatePrefix + 1)
		local path = table.concat(args, " ", 2)
		obsidian_exec(bufnr, CMD.new_from_template, { template_name, path }, function(result)
			if result and result.uri then
				edit_uri(result.uri)
			end
		end)
		return
	end

	obsidian_exec(bufnr, CMD.new, { opts.args }, function(result)
		if result and result.uri then
			edit_uri(result.uri)
		end
	end)
end, {
	nargs = "*",
	desc = "Create new note (default template) or from template",
	complete = function(_, cmdline, _)
		local arg = vim.fn.matchstr(cmdline, [[\v\S+$]])
		if not arg or arg == "" or arg == "ObsidianNew" then
			return vim.iter(list_templates(vim.api.nvim_get_current_buf()))
				:map(function(t)
					return TemplatePrefix .. t
				end)
				:totable()
		end
		if arg:match("^" .. TemplatePrefix) then
			return vim.iter(list_templates(vim.api.nvim_get_current_buf()))
				:map(function(t)
					return TemplatePrefix .. t
				end)
				:totable()
		end
		return {}
	end,
})

vim.api.nvim_create_user_command("ObsidianRename", function()
	local bufnr = vim.api.nvim_get_current_buf()
	local new_path, err = frontmatter.rename_buffer_from_frontmatter(bufnr)
	if not new_path then
		local level = err and err:match("^target already exists:") and vim.log.levels.ERROR or vim.log.levels.WARN
		vim.notify("ObsidianRename: " .. (err or "rename failed"), level)
		return
	end

	if err == "filename unchanged" then
		vim.notify("ObsidianRename: filename unchanged", vim.log.levels.INFO)
		return
	end

	local new_basename = vim.fn.fnamemodify(new_path, ":t:r")
	vim.notify("Renamed to " .. new_basename, vim.log.levels.INFO)
end, {
	desc = "Rename file from frontmatter: tag1_tag2++aliases[1]",
})

-- auto formatting
local format_group = vim.api.nvim_create_augroup("liu/obsidian_ls/format", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local buf = ev.buf
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client or client.name ~= "obsidian_ls" then
			return
		end

		local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
		if filename == "README.md" then
			return
		end

		vim.api.nvim_create_autocmd("BufWritePre", {
			group = format_group,
			buffer = buf,
			callback = function()
				if not vim.api.nvim_buf_is_valid(buf) then
					return
				end
				pcall(vim.cmd, "undojoin")
				local frontmatter_changed = frontmatter.sync(buf)
				if frontmatter_changed then
					pcall(vim.cmd, "undojoin")
				end
				vim.lsp.buf.format({ bufnr = buf, id = client.id })
			end,
		})
	end,
})
