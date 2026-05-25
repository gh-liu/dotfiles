-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#buf_ls
vim.api.nvim_create_autocmd("BufReadPost", {
	group = vim.api.nvim_create_augroup("liu.lsp.buf_ls", { clear = true }),
	pattern = { "buf.yaml", "buf.gen.yaml" },
	callback = function()
		vim.schedule(function()
			vim.lsp.start(vim.lsp.config["buf_ls"])
		end)
	end,
})
---@type vim.lsp.Config
return {}
