local formatting = require("liu.plugins.formatting")
local CMD = {
	new = "obsidian.new",
	new_from_template = "obsidian.newFromTemplate",
	list_templates = "obsidian.listTemplates",
}

local TemplatePrefix = ":"

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

local function list_templates()
	local command = { command = CMD.list_templates, arguments = {} }
	local result = vim.lsp.buf_request_sync(0, "workspace/executeCommand", command)
	if not result or not result[1] or not result[1].result or not result[1].result.templates then
		return {}
	end
	return result[1].result.templates
end

local edit_uri = function(uri)
	local fname = vim.uri_to_fname(uri)
	vim.cmd("edit " .. vim.fn.fnameescape(fname))
end

vim.api.nvim_create_user_command("ObsidianNew", function(opts)
	local args = opts.fargs
	if #args > 0 and args[1]:match("^" .. TemplatePrefix) then
		local template_name = args[1]:sub(3)
		local path = args[2] or ""
		obsidian_exec(CMD.new_from_template, { template_name, path }, function(result)
			if result and result.uri then
				edit_uri(result.uri)
			end
		end)
		return
	end

	obsidian_exec(CMD.new, { opts.args }, function(result)
		if result and result.uri then
			edit_uri(result.uri)
		end
	end)
end, {
	nargs = "*",
	desc = "Create new note (default template) or from template",
	complete = function(_, cmdline, _)
		local arg = vim.fn.matchstr(cmdline, [[\v\S+$]])
		if not arg or arg == "" then
			return {}
		end
		if arg:match("^" .. TemplatePrefix) then
			return vim.iter(list_templates())
				:map(function(t)
					return TemplatePrefix .. t
				end)
				:totable()
		end
		return {}
	end,
})

-- auto formatting
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local buf = ev.buf
		local clients = vim.lsp.get_clients({ name = "obsidian_ls" })
		---@type vim.lsp.Client|nil
		local client = #clients > 0 and clients[1] or nil
		if client then
			vim.api.nvim_create_autocmd("BufWritePre", {
				buffer = buf,
				callback = function()
					vim.lsp.buf.format({ bufnr = buf, id = client.id })
				end,
			})
		end
	end,
})
