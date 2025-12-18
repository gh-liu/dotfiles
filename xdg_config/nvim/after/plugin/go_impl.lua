-- @need-install: go install github.com/josharian/impl@latest
local Impl = {}
-- append text after node
Impl.append_text = function(node, text)
	local _, _, pos, _ = node:range()
	pos = pos + 1
	-- insert an empty line
	vim.api.nvim_buf_set_lines(0, pos, pos, false, {})
	pos = pos + 1
	vim.api.nvim_buf_set_lines(0, pos, pos, false, vim.split(text, "\n"))
end

-- impl interface of package for struct(generate text)
Impl.gen_text = function(struct, package, interface)
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

Impl.get_struct_node = function()
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

Impl.impl = function()
	local tsnode = Impl.get_struct_node()
	if not tsnode then
		vim.print("No type identifier found under cursor")
		return
	end

	local struct_name = vim.treesitter.get_node_text(tsnode, 0)

	local bufnr = vim.api.nvim_get_current_buf()

	-- local utils = require("fzf-lua.utils")
	-- local make_entry = require("fzf-lua.make_entry")
	-- require("fzf-lua").fzf_live(function(args)
	-- 	local query = args[1] or ""
	-- 	local kind_interface = vim.lsp.protocol.SymbolKind.Interface
	-- 	local method = vim.lsp.protocol.Methods.workspace_symbol
	-- 	return function(cb)
	-- 		local params = {
	-- 			query = query,
	-- 			kind = kind_interface,
	-- 		}
	-- 		local client = vim.lsp.get_clients({ name = "gopls", bufnr = bufnr })[1]
	-- 		if not client then
	-- 			cb(nil)
	-- 		end
	-- 		local handler = function(err, result, ctx)
	-- 			result = vim.lsp.util.symbols_to_items(result, 0, client.offset_encoding)
	-- 			result = vim.iter(result)
	-- 				:filter(function(item)
	-- 					return item.kind == "Interface"
	-- 				end)
	-- 				:each(function(item)
	-- 					-- cb(item.text)
	-- 					local entry = item
	-- 					local symbol = entry.text
	-- 					entry.text = nil
	-- 					local opts = {}
	-- 					local entry0 = make_entry.lcol(entry, opts)
	-- 					local entry1 = make_entry.file(entry0, opts)
	-- 					entry1 = symbol .. utils.nbsp .. entry1
	-- 					cb(entry1)
	-- 				end)
	-- 			cb(nil)
	-- 		end
	-- 		client:request(method, params, handler, bufnr)
	-- 	end
	-- end, {
	-- 	prompt = "Go Impl> ",
	-- 	previewer = "builtin",
	-- 	actions = {
	-- 		default = function(selected, opts)
	-- 			local select1 = selected[1]
	-- 			local interfaceName, containerName = select1:match("%[Interface%]%s+([%w/%.]+)%s+in%s+([%w/%.]+)")
	-- 			-- vim.print(interfaceName, containerName)
	--
	-- 			local symbol_name = interfaceName
	-- 			local symbol_names = vim.split(symbol_name, "%.")
	-- 			local interface_name = symbol_names[#symbol_names]
	-- 			local package_name = containerName
	-- 			vim.schedule(function()
	-- 				local lines = Impl.gen_text(struct_name, package_name, interface_name)
	-- 				Impl.append_text(tsnode:parent():parent(), lines)
	-- 			end)
	-- 		end,
	-- 	},
	-- })

	require("snacks").picker({
		title = "Go Impl",
		finder = function(opts, ctx)
			local kind_interface = vim.lsp.protocol.SymbolKind.Interface
			local method = vim.lsp.protocol.Methods.workspace_symbol
			local param = {
				query = ctx.filter.search,
				kind = kind_interface,
			}
			local snacks_lsp = require("snacks.picker.source.lsp")
			return function(cb)
				snacks_lsp.request(bufnr, method, function()
					return param
				end, function(client, result, params)
					local items = snacks_lsp.results_to_items(client, result, {
						default_uri = params.textDocument and params.textDocument.uri or nil,
						filter = function(item)
							return item.kind == kind_interface
						end,
					})
					for _, item in ipairs(items) do
						---@diagnostic disable-next-line: await-in-sync
						cb(item)
					end
				end)
			end
		end,
		live = true,
		format = "lsp_symbol",
		actions = {
			go_impl = function(self, item, action)
				local symbol_name = item.item.name
				local symbol_names = vim.split(symbol_name, "%.")
				local interface_name = symbol_names[#symbol_names]
				local package_name = item.item.containerName
				self:close()
				-- vim.print(symbol_name, package_name)
				vim.schedule(function()
					local lines = Impl.gen_text(struct_name, package_name, interface_name)
					Impl.append_text(tsnode:parent():parent(), lines)
				end)
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

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client or client.name ~= "gopls" then
			return
		end
		vim.keymap.set("n", "grI", Impl.impl, { buffer = args.buf, desc = "Go impl" })
	end,
})
