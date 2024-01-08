local api = vim.api
local fn = vim.fn
local ms = vim.lsp.protocol.Methods

-- for the sake of operatorfunc
local require_path = "liu.lsp.sqls"

local M = {
	client = nil,
}

-- https://github.com/sqls-server/sqls/blob/master/internal/handler/execute_command.go#L22
---@type table
M.commands = {
	execute_query = "executeQuery",
	show_connections = "showConnections",
	show_databases = "showDatabases",
	show_schemas = "showSchemas",
	show_tables = "showTables",
	switch_connection = "switchConnections",
	switch_database = "switchDatabase",
}

---@param result string
---@param mods? string
local preview_result = function(result, mods)
	local tempfile = fn.tempname() .. ".dbout"
	local bufnr = fn.bufnr(tempfile, true)
	mods = mods or "botright"
	api.nvim_buf_set_lines(bufnr, 0, 1, false, vim.split(result, "\n"))
	vim.cmd(("%s pedit %s"):format(mods, tempfile))
	local options = {
		filetype = "dbout",
		modified = false,
		modifiable = false,
		buflisted = false,
		readonly = true,
	}
	for option, value in pairs(options) do
		api.nvim_set_option_value(option, value, { buf = bufnr })
	end
end

---@type lsp.Handler
local show_handler = function(err, result, context, config)
	if err then
		vim.notify("sqls: " .. err.message, vim.log.levels.ERROR)
		return
	end
	if not result then
		return
	end
	if result == "" then
		vim.notify("sqls: result is empty", vim.log.levels.WARN)
		return
	end
	preview_result(result)
end

---@type lsp.Handler
local switch_handler = function(err, result, context, config)
	if err then
		vim.notify("sqls: " .. err.message, vim.log.levels.ERROR)
	else
		local argument = context.params.arguments[1]
		local command = context.params.command
		vim.notify("sqls: " .. command .. " to " .. argument, vim.log.levels.INFO)
	end
end

---@type lsp.Handler
local execute_handler = function(err, result, context, config)
	show_handler(err, result, context, config)
end

---@param client lsp.Client
---@param bufnr integer
M.on_attach = function(client, bufnr)
	---@diagnostic disable-next-line: assign-type-mismatch
	client.server_capabilities.executeCommandProvider = true
	M.client = client

	local gen_sqls_lsp_command = function(command)
		local cmd = "Sqls"
		local strs = vim.split(command, "_", {})
		for _, str in ipairs(strs) do
			cmd = cmd .. str:sub(1, 1):upper() .. str:sub(2)
		end
		return cmd
	end

	for command, lsp_command in pairs(M.commands) do
		if vim.startswith(command, "show_") then
			api.nvim_buf_create_user_command(bufnr, gen_sqls_lsp_command(command), function(opts)
				M.execute_command({ command = lsp_command }, show_handler)
			end, {
				desc = command,
				nargs = 0,
			})
		end

		if vim.startswith(command, "switch_") then
			api.nvim_buf_create_user_command(bufnr, gen_sqls_lsp_command(command), function(opts)
				M.execute_command({
					command = lsp_command,
					arguments = { opts.fargs[1] },
				}, switch_handler)
			end, {
				desc = command,
				nargs = 1,
				complete = function()
					local show_command = lsp_command:gsub("switch", "show")
					local show_command = show_command .. "s" -- TODO switchConnections alreay has s suffix
					local resp =
						vim.lsp.buf_request_sync(bufnr, ms.workspace_executeCommand, { command = show_command })
					if resp and #resp > 0 then
						local result = resp[1].result
						if result then
							return vim.split(result, "\n", {})
						end
					end
				end,
			})
		end

		if vim.startswith(command, "execute_") then
			api.nvim_buf_create_user_command(bufnr, gen_sqls_lsp_command(command), function(opts)
				local show_vertical = true

				local range
				local line1 = opts.line1
				local line2 = opts.line2
				if line1 > 0 and line2 > 0 then
					local line2text = vim.api.nvim_buf_get_lines(bufnr, line2 - 1, line2, false)[1]
					range = vim.lsp.util.make_given_range_params({ line1, 0 }, { line2, #line2text - 1 }).range
				end

				M.execute_command({
					command = lsp_command,
					arguments = { vim.uri_from_bufnr(bufnr), show_vertical },
					range = range,
				}, execute_handler)
			end, {
				desc = command,
				nargs = 0,
				range = true,
			})

			vim.keymap.set({ "n", "x" }, "<leader>q", function()
				vim.o.operatorfunc = "v:lua.require'" .. require_path .. "'.operator_callback"
				vim.api.nvim_feedkeys("g@", "n", false)
			end, { buffer = bufnr })
		end
	end
end

---@param params lsp.ExecuteCommandParams
---@param handler lsp.Handler
M.execute_command = function(params, handler)
	M.client.request(ms.workspace_executeCommand, params, handler, 0)
end

---@alias operator_callback fun(type: '"block"'|'"line"'|'"char"')
---@type operator_callback
M.operator_callback = function(type)
	local show_vertical = false
	local range
	local _, lnum1, col1, _ = unpack(fn.getpos("'["))
	local _, lnum2, col2, _ = unpack(fn.getpos("']"))
	if type == "block" then
		vim.notify("sqls: does not support block-wise ranges!", vim.log.levels.ERROR)
		return
	end

	if type == "line" then
		range = vim.lsp.util.make_given_range_params({ lnum1, 0 }, { lnum2, math.huge }).range
		range["end"].character = range["end"].character - 1
	end
	if type == "char" then
		range = vim.lsp.util.make_given_range_params({ lnum1, col1 - 1 }, { lnum2, col2 - 1 }).range
	end

	M.execute_command({
		command = M.commands.execute_query,
		arguments = { vim.uri_from_bufnr(0), show_vertical },
		range = range,
	}, execute_handler)
end

M.parse_env_of_dadbod = function()
	local url = os.getenv("DATABASE_URL")
	if not url then
		return
	end

	local conn
	if vim.startswith(url, "mysql://") then
		-- mysql://[<user>[:<password>]@][<host>[:<port>]]/[database]
		local _, _, user, password, host, port, database = url:find("mysql://(%a+):(.+)@([%d.]+):(%d+)/(.+)")
		password = vim.uri_decode(password)
		conn = {
			driver = "mysql",
			alias = string.format("%s(%s:%d)", database, host, port),
			dataSourceName = string.format("%s:%s@tcp(%s:%d)/%s", user, password, host, port, database),
		}
	end

	-- TODO: postgresql
	-- TODO: sqlserver
	-- TODO: sqlite

	return conn
end

return M
