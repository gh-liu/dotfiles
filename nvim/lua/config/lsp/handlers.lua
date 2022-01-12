local cmp_nvim_lsp = require("cmp_nvim_lsp")
local lsputils = require("config.lsp.utils")

local M = {}

M.setup = function()
	-- vim.lsp.set_log_level("debug")

	vim.cmd("highlight default link LspCodeLens WarningMsg")
	vim.cmd("highlight default link LspCodeLensText WarningMsg")
	vim.cmd("highlight default link LspCodeLensTextSign LspCodeLensText")
	vim.cmd("highlight default link LspCodeLensTextSeparator Boolean")
	vim.cmd([[autocmd BufEnter,CursorHold,InsertLeave * lua require("config.lsp.handlers").setup_codelens_refresh()]])
end

M.capabilities = cmp_nvim_lsp.update_capabilities(vim.lsp.protocol.make_client_capabilities())

M.on_attach = function(client, bufnr)
	local function buf_set_keymap(...)
		vim.api.nvim_buf_set_keymap(bufnr, ...)
	end
	local function buf_set_option(...)
		vim.api.nvim_buf_set_option(bufnr, ...)
	end

	-- Enable completion triggered by <c-x><c-o>
	buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

	-- Mappings.
	local opts = {
		noremap = true,
		silent = true,
	}

	-- See `:help vim.lsp.*` for documentation on any of the below functions
	-- go-to-definition
	-- buf_set_keymap('n','<c-]>','<cmd>lua vim.lsp.buf.definition()<cr>', opts)
	-- buf_set_keymap('n', '<c-d>', '<cmd>lua vim.lsp.buf.definition()<cr>', opts)
	-- buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<cr>', opts)
	-- buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.declaration()<cr>', opts)
	-- buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.type_definition()<cr>', opts)
	-- find-references
	-- buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>', opts)
	-- hover
	buf_set_keymap("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>", opts)
	buf_set_keymap("n", "<c-k>", "<cmd>lua vim.lsp.buf.signature_help()<cr>", opts)
	-- completion
	-- rename
	buf_set_keymap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>", opts)
	-- format
	-- buf_set_keymap('n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
	-- refactor
	-- buf_set_keymap('n', '<leader>a', '<cmd>lua vim.lsp.buf.code_action()<cr>', opts)
	-- diagnostic
	-- buf_set_keymap('n', '<space>e', '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
	-- buf_set_keymap('n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
	buf_set_keymap("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
	buf_set_keymap("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
	-- something else
	-- buf_set_keymap('n', 'g0', '<cmd>lua vim.lsp.buf.document_symbol()<cr>', opts)
	-- buf_set_keymap('n', 'gW', '<cmd>lua vim.lsp.buf.workspace_symbol()<cr>', opts)
	-- buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
	-- buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
	-- buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
	buf_set_keymap("n", "<leader>F", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
	buf_set_keymap("n", "<leader>L", "<cmd>lua vim.lsp.codelens.run()<CR>", opts)
end

M.setup_auto_format = function(ft, command)
	if not command then
		command = "lua vim.lsp.buf.formatting_sync()"
	end
	vim.cmd(string.format("autocmd BufWritePre *.%s %s", ft, command))
end

M.is_codelens_supported = false

M.setup_codelens_refresh = function()
	if not M.is_codelens_supported then
		M.is_codelens_supported = lsputils.check_capabilities("code_lens")
		if not M.is_codelens_supported then
			-- vim.cmd([[ echo "code lens not supported by your lsp"]])
			return
		end
	end
	if M.is_codelens_supported then
		vim.lsp.codelens.refresh()
	end
end

return M
