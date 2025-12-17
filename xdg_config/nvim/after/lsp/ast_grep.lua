vim.api.nvim_create_user_command("AstGrep", function(cmd_args)
	if cmd_args.fargs[1] == "playground" then
		vim.ui.open("https://ast-grep.github.io/playground.html")
		return
	end

	if cmd_args.fargs[1] == "diagnostics" then
		local client = vim.lsp.get_clients({ name = "ast_grep" })[1]
		if not client then
			return
		end
		local ns = vim.lsp.diagnostic.get_namespace(client.id)
		vim.diagnostic.setqflist({ namespace = ns, open = true })
		return
	end
end, {
	nargs = "?",
	complete = function()
		return {
			"playground",
			"diagnostics",
		}
	end,
})

-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ast_grep
-- @need-install: uv tool install --force ast-grep-cli
-- cargo install ast-grep
return {
	on_attach = function(client, buf)
		local ns = vim.lsp.diagnostic.get_namespace(client.id)
		vim.diagnostic.enable(false, { ns_id = ns })
	end,
}
