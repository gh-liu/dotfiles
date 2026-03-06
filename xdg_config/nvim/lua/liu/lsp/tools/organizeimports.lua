local M = {}

---@param client vim.lsp.Client
---@param bufnr integer
---@param only string[]
---@param opts? { title_pattern?: string }
local apply_code_actions = function(client, bufnr, only, opts)
	if not client then
		return
	end

	local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
	params.context = { only = only }

	local response = client:request_sync("textDocument/codeAction", params, 3000, bufnr)
	local actions = response and response.result
	if not actions then
		return
	end

	for _, action in ipairs(actions) do
		if opts and opts.title_pattern then
			local title = action.title or ""
			if not title:match(opts.title_pattern) then
				goto continue
			end
		end

		if action.edit then
			vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
		end

		if action.command then
			client:exec_cmd(action.command, { bufnr = bufnr })
		end

		::continue::
	end
end

local servers = {
	ruff = function(client, bufnr)
		apply_code_actions(client, bufnr, { "source.organizeImports", "source.organizeImports.ruff" })
	end,
	ty = function(client, bufnr)
		-- `ty` provides "Add import" as quick fixes.
		apply_code_actions(client, bufnr, { "quickfix" }, { title_pattern = "^[Aa]dd import" })
	end,
	gopls = function(client, bufnr)
		apply_code_actions(client, bufnr, { "source.organizeImports" })
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
