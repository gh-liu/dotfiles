-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#ast_grep
-- @need-install: cargo install ast-grep
return {
	on_attach = function(client, buf)
		local ns = vim.lsp.diagnostic.get_namespace(client.id)
		vim.diagnostic.enable(false, { ns_id = ns })
	end,
}
