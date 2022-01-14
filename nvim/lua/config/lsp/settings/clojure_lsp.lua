local lsp = require("lspconfig")
local handler = require("config.lsp.handlers")

-- ====== Clojure ======
lsp.clojure_lsp.setup({
	capabilities = handler.capabilities,
	on_attach = handler.on_attach,
})
