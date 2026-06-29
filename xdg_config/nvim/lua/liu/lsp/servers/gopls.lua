local M = {}

local IMPL = {}

IMPL.get_struct_node = function()
	local tsnode = vim.treesitter.get_node()
	if
		not tsnode
		or (
			tsnode:type() ~= "type_identifier"
			or tsnode:parent():type() ~= "type_spec"
			or tsnode:parent():parent():type() ~= "type_declaration"
		)
	then
		return
	end
	return tsnode
end

IMPL.impl_interface = function(bufnr, client, interface)
	local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
	local command = {
		command = "gopls.implement_interface",
		arguments = {
			{
				Location = {
					uri = params.textDocument.uri,
					range = params.range,
				},
			},
		},
		formAnswers = {
			{
				id = "interface",
				value = interface,
			},
		},
	}

	client:request(vim.lsp.protocol.Methods.workspace_executeCommand, command, function(err)
		if err then
			vim.schedule(function()
				vim.notify(err.message or vim.inspect(err), vim.log.levels.ERROR)
			end)
		end
	end, bufnr)
end

IMPL.interface_item = function(value)
	return {
		text = value,
		value = value,
	}
end

IMPL.impl = function(client, bufnr)
	local tsnode = IMPL.get_struct_node()
	if not tsnode then
		vim.print("No type identifier found under cursor")
		return
	end

	require("snacks").picker({
		title = "Go Impl",
		finder = function(opts, ctx)
			local param = {
				source = "workspaceSymbol",
				query = ctx.filter.search,
				config = {
					Kinds = { vim.lsp.protocol.SymbolKind.Interface },
				},
			}
			return function(cb)
				local response = ctx.async:schedule(function()
					return client:request_sync("interactive/listEnum", param, 1000, bufnr)
				end)
				if not response then
					return
				end

				if response.err then
					vim.schedule(function()
						vim.notify(response.err.message or vim.inspect(response.err), vim.log.levels.ERROR)
					end)
					return
				end

				for _, entry in ipairs(response.result or {}) do
					cb(IMPL.interface_item(entry.value))
				end
			end
		end,
		live = true,
		format = "text",
		layout = { preset = "select", preview = false },
		actions = {
			go_impl = function(self, item, action)
				self:close()
				IMPL.impl_interface(bufnr, client, item.value)
			end,
		},
		win = {
			input = {
				keys = {
					["<cr>"] = { "go_impl", mode = { "n", "i" } },
				},
			},
		},
	})
end

---@param client vim.lsp.Client
---@param bufnr integer
M.on_attach = function(client, bufnr)
	vim.keymap.set("n", "grI", function()
		IMPL.impl(client, bufnr)
	end, { buffer = bufnr, desc = "Go impl" })
end

return M
