local lsp = require("lspconfig")
local handler = require("config.lsp.handlers")

-- ====== Bash ======
lsp.vimls.setup({
	capabilities = handler.capabilities,
	on_attach = handler.on_attach,
})
