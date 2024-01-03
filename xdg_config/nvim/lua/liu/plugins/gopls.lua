local api = vim.api
local fn = vim.fn
local ms = vim.lsp.protocol.Methods

-- local require_path = "liu.plugins.gopls"

local M = {
	---@type lsp.Client
	client = nil,
}

-- https://github.com/golang/tools/blob/master/gopls/doc/commands.md
---@type table
M.commands = {
	add_dependency = function(client, bufnr, cmd_args)
		local path = client.workspace_folders and client.workspace_folders[1] and client.workspace_folders[1].name
		local bufnr = vim.fn.bufnr(path .. "/go.mod", true)
		return {
			{
				GoCmdArgs = { cmd_args.fargs[1] },
				AddRequire = true,
				URI = vim.uri_from_bufnr(bufnr),
			},
		}
	end,
	add_import = function(client, bufnr, cmd_args)
		return {
			{
				ImportPath = cmd_args.fargs[1],
				URI = vim.uri_from_bufnr(bufnr),
			},
		}
	end,
	go_get_package = function(client, bufnr, cmd_args)
		return {
			{
				Pkg = cmd_args.fargs[1],
				AddRequire = true,
				URI = vim.uri_from_bufnr(bufnr),
			},
		}
	end,
}

---@type lsp.Handler
local add_handler = function(err, result, context, config)
	if err then
		vim.notify("gopls: " .. err.message, vim.log.levels.ERROR)
		return
	end
end

---@param client lsp.Client
---@param bufnr integer
M.on_attach = function(client, bufnr)
	M.client = client

	local gen_gopls_lsp_command = function(command)
		local cmd = "Gopls"
		local strs = vim.split(command, "_", {})
		for _, str in ipairs(strs) do
			cmd = cmd .. str:sub(1, 1):upper() .. str:sub(2)
		end
		return cmd
	end

	for command, fn in pairs(M.commands) do
		api.nvim_buf_create_user_command(bufnr, gen_gopls_lsp_command(command), function(args)
			M.execute_command({
				command = "gopls." .. command,
				arguments = fn(client, bufnr, args),
			}, add_handler)
		end, {
			desc = command,
			nargs = 1,
		})
	end
end

---@param params lsp.ExecuteCommandParams
---@param handler lsp.Handler
M.execute_command = function(params, handler)
	M.client.request(ms.workspace_executeCommand, params, handler, 0)
end

return M
