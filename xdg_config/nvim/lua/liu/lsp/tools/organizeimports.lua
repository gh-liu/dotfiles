local M = {}

local py_organizeimports = function(client, bufnr)
	if not client then
		return
	end
	local params = {
		command = "pyright.organizeimports",
		arguments = { vim.uri_from_bufnr(bufnr) },
	}
	client:exec_cmd(params, { bufnr = bufnr })
	-- client:request("workspace/executeCommand", params, nil, bufnr)
	-- client:request_sync("workspace/executeCommand", params, 1000, bufnr)
end

local servers = {
	delance = py_organizeimports,
	gopls = function(client, bufnr)
		if not client then
			return
		end

		local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
		params.context = { only = { "source.organizeImports" } }
		local result = client:request_sync("textDocument/codeAction", params, 1000, bufnr)
		if result and result[1] then
			for _, r in pairs(result[1]) do
				if r.edit then
					vim.lsp.util.apply_workspace_edit(r.edit, client.offset_encoding)
				end
			end
		end
	end,
}

M.setup = function() end

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client then
			return
		end
		local organizeimports = servers[client.name]
		if organizeimports then
			local bufnr = args.buf
			vim.api.nvim_create_autocmd("BufWritePre", {
				desc = string.format("%s organizeimports [%d]", client.name, bufnr),
				callback = function()
					organizeimports(client, bufnr)
				end,
				buffer = bufnr,
			})
		end
	end,
})

return M
