local api = vim.api
local fn = vim.fn
local ms = vim.lsp.protocol.Methods

---@param command lsp.Command
---@param ctx? {bufnr: integer, client_id: integer}
vim.lsp.commands["gopls.test"] = function(command, ctx)
	vim.print(command)
end

-- local require_path = "liu.lsp.gopls"

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

	vim.keymap.set("n", "<leader>gi", function()
		M.impl()
	end, { buffer = bufnr, desc = "Go impl" })
end

---@param params lsp.ExecuteCommandParams
---@param handler lsp.Handler
M.execute_command = function(params, handler)
	M.client.request(ms.workspace_executeCommand, params, handler, 0)
end

local append_text = function(node, text)
	local _, _, pos, _ = node:range()
	pos = pos + 1
	-- insert an empty line
	api.nvim_buf_set_lines(0, pos, pos, false, {})
	pos = pos + 1
	api.nvim_buf_set_lines(0, pos, pos, false, vim.split(text, "\n"))
end

local gen_impl_text = function(struct, package, interface)
	local receiver = string.lower(string.sub(struct, 1, 2))
	local dirname = vim.fn.fnameescape(vim.fn.expand("%:p:h"))

	local cmd = {
		"impl",
		"-dir",
		dirname,
		string.format("%s *%s", receiver, struct),
		string.format("%s.%s", package, interface),
	}
	local obj = vim.system(cmd, { text = true }):wait(1000)
	if
		obj.code == 1
		and (string.find(obj.stderr, "unrecognized interface:") or string.find(obj.stderr, "couldn't find"))
	then
		-- if not find the 'packageName.interfaceName', then try just `interfaceName`
		cmd[#cmd] = interface
		obj = vim.system(cmd, { text = true }):wait(1000)
	end

	if obj.code == 1 then
		vim.notify(obj.stderr, vim.log.levels.ERROR)
		return
	end
	return obj.stdout
end

local function dynamic_get_workspace_symbols_requester(bufnr, kind)
	local lsp2 = require("liu.lsp.helper")
	local channel = require("plenary.async.control").channel
	local cancel = function() end
	return function(prompt)
		cancel()
		local tx, rx = channel.oneshot()
		_, cancel = lsp2.workspace_symbol_async(bufnr, {
			query = prompt,
			kind = kind,
		}, tx)
		local err, res = rx()
		assert(not err, err)
		return lsp2.symbols_to_items(res or {}, bufnr) or {}
	end
end

M.impl = function()
	local ts = vim.treesitter
	local tsnode = ts.get_node()
	if
		not tsnode
		or (
			tsnode:type() ~= "type_identifier"
			or tsnode:parent():type() ~= "type_spec"
			or tsnode:parent():parent():type() ~= "type_declaration"
		)
	then
		vim.print("No type identifier found under cursor")
		return
	end
	local struct_name = ts.get_node_text(tsnode, 0)

	local buf = api.nvim_get_current_buf()

	local opts = {}
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local actions = require("telescope.actions")
	local actions_set = require("telescope.actions.set")
	local actions_state = require("telescope.actions.state")
	local make_entry = require("telescope.make_entry")
	local config_values = require("telescope.config").values

	pickers
		.new(opts, {
			prompt_title = "Go Impl",
			finder = finders.new_dynamic({
				entry_maker = make_entry.gen_from_lsp_symbols(opts),
				fn = dynamic_get_workspace_symbols_requester(buf, vim.lsp.protocol.SymbolKind.Interface),
			}),
			previewer = config_values.qflist_previewer(opts),
			sorter = config_values.generic_sorter(),
			attach_mappings = function(prompt_bufnr)
				actions_set.select:replace(function(_, _)
					local entry = actions_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if not entry then
						return
					end

					-- if symbol contains dot eg: sort.Interface, the symbol_name will contains the sort package name,
					-- so only use the name of  interface part
					local symbol_names = vim.split(entry.symbol_name, "%.")
					local interface_name = symbol_names[#symbol_names]
					local package_name = entry.value.symbol.containerName

					vim.schedule(function()
						local lines = gen_impl_text(struct_name, package_name, interface_name)
						append_text(tsnode:parent():parent(), lines)
					end)
				end)
				return true
			end,
		})
		:find()
end

return M
