local ok, _ = pcall(require, "lspconfig")
if not ok then
	return
end
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Levels by name: "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF"
vim.lsp.set_log_level("OFF")

require("lspconfig.ui.windows").default_options.border = config.borders

-- keymaps
autocmd("LspAttach", {
	group = augroup("UserLspAttachKeymaps", { clear = true }),
	callback = function(args)
		local bufnr = args.buf

		vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
		-- vim.bo[bufnr].tagfunc = "v:lua.vim.lsp.tagfunc"
		-- vim.bo[bufnr].formatexpr = "v:lua.vim.lsp.formatexpr(#{timeout_ms:250})"

		local nmap = function(keys, func, desc)
			if desc then
				desc = "LSP: " .. desc
			end
			vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
		end

		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client.supports_method("textDocument/rename") then
			nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
		end

		nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
		nmap("<leader>cl", vim.lsp.codelens.run, "[C]ode [L]en")

		-- nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
		nmap("<leader>vd", "<cmd>vsplit | lua vim.lsp.buf.definition()<CR>", "[G]oto [D]efinition")
		-- nmap("gD", vim.lsp.buf.type_definition, "[G]oto Type [D]efinition")

		-- nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

		-- nmap("K", vim.lsp.buf.hover, "Hover Documentation")
		-- nmap("<C-k>", vim.lsp.buf.signature_help, "Signature Documentation")

		nmap("<leader>wa", function()
			vim.lsp.buf.add_workspace_folder()
		end)
		nmap("<leader>wr", function()
			local wsfs = vim.lsp.buf.list_workspace_folders()

			vim.ui.select(wsfs, {
				prompt = "Remove Workspace Folder",
				format_item = function(item)
					return "Remove: " .. item
				end,
			}, function(choice)
				vim.lsp.buf.remove_workspace_folder(choice)
			end)
		end)
		nmap("<leader>wl", function()
			vim.print(vim.lsp.buf.list_workspace_folders())
		end)
	end,
})

autocmd("LspProgress", {
	group = augroup("UserLspProgress", { clear = true }),
	callback = function(args)
		if true then
			return
		end

		if not args.data or not args.data.result then
			return
		end
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		local value = args.data.result.value

		-- percentage
		local str = string.format(
			"%s[%s]:%s%s",
			client.name,
			value.title,
			value.kind,
			value.message and "(" .. value.message .. ")" or ""
		)
		if value.percentage then
			str = string.format("%s[%d%%]", str, value.percentage)
		end

		vim.notify(str, vim.log.levels.WARN)

		-- vim.print(vim.lsp.status())
	end,
})

-- commands
local autoformat = true
autocmd("LspAttach", {
	group = augroup("UserLspAttachCommands", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)

		if client.supports_method("textDocument/formatting") then
			local bufnr = args.buf

			local format = function()
				vim.lsp.buf.format({
					async = false,
					filter = function(client)
						return true
					end,
				})
			end

			vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
				format()
			end, {
				desc = "Format current buffer with LSP",
			})

			vim.api.nvim_buf_create_user_command(bufnr, "FormatToggle", function()
				autoformat = not autoformat
				vim.notify("autoformatting = " .. tostring(autoformat), vim.log.levels.WARN)
			end, {})

			autocmd("BufWritePre", {
				group = augroup("UserLspAttachAutoFormat", { clear = true }),
				buffer = bufnr,
				callback = function()
					if autoformat then
						format()
					end
				end,
			})

			-- if vim.o.filetype == "go" then
			-- 	vim.api.nvim_buf_create_user_command(bufnr, "GoOrganizeImports", function(_)
			-- 		vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true })
			-- 	end, { desc = "Organize imports for golang" })
			-- end
		end
	end,
})

-- codelens
autocmd("LspAttach", {
	group = augroup("UserLspAttachCodelens", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client.supports_method("textDocument/codeLens") then
			local bufnr = args.buf
			autocmd({ "CursorHold", "InsertLeave" }, {
				callback = function()
					vim.lsp.codelens.refresh()
				end,
				buffer = 0,
			})
		end
	end,
})

autocmd("LspAttach", {
	group = augroup("UserLspAttachInlayHint", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client.supports_method("textDocument/inlayHint") then
			local bufnr = args.buf
			if vim.lsp.inlay_hint then
				vim.lsp.inlay_hint(bufnr, true)
				return
			end
		end
	end,
})

autocmd("LspAttach", {
	group = augroup("UserLspAttachDocumentHighlight", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		local bufnr = args.buf
		if client.server_capabilities.documentHighlightProvider then
			vim.api.nvim_create_augroup("UserLspDocumentHighlight", {
				clear = false,
			})
			vim.api.nvim_clear_autocmds({
				buffer = bufnr,
				group = "UserLspDocumentHighlight",
			})
			vim.api.nvim_create_autocmd({ "CursorHold" }, {
				group = "UserLspDocumentHighlight",
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.document_highlight()
				end,
			})
			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				group = "UserLspDocumentHighlight",
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.clear_references(bufnr)
				end,
			})
		end
	end,
})

-- lsp settings
local servers = {
	gopls = {},
	rust_analyzer = {},
	lua_ls = {
		-- https://github.com/LuaLS/lua-language-server/wiki/Settings
		Lua = {
			hint = { enable = true },
			format = { enable = false }, -- instead of using stylua
			telemetry = { enable = false },
			workspace = { checkThirdParty = false },
			diagnostics = { globals = { "vim" } },
		},
	},
	vimls = {},
	bashls = {},
	jsonls = {
		-- https://code.visualstudio.com/docs/getstarted/settings serach `json.`
		json = {
			format = { enable = true },
			schemas = {},
			validate = { enable = true },
		},
	},
	yamlls = {
		-- https://github.com/redhat-developer/yaml-language-server#language-server-settings
		yaml = {
			format = { enable = true },
			schemaStore = { enable = true },
			validate = { enable = true },
		},
	},
	tsserver = {},
	zls = {
		-- Download from https://zig.pm/zls/downloads/x86_64-linux/bin/zls
		-- https://github.com/zigtools/zls#configuration-options
		zls = {
			enable_inlay_hints = false,
			inlay_hints_show_builtin = true,
			inlay_hints_exclude_single_argument = true,
			inlay_hints_hide_redundant_param_names = false,
			inlay_hints_hide_redundant_param_names_last_token = false,
		},
	},
}

-- setup neodev BEFORE lspconfig
require("neodev").setup({
	setup_jsonls = false,
})

local on_attach = function(client, bufnr)
	-- local name = client.name
	-- vim.print(client.server_capabilities)
	-- vim.print(client.server_capabilities.executeCommandProvider)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

local handlers = {
	["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = config.borders }),
	["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = config.borders }),
}

vim.lsp.handlers["workspace/diagnostic/refresh"] = function(_, _, ctx)
	vim.notify("Diagnostic Refresh", vim.log.levels.WARN)
	local ns = vim.lsp.diagnostic.get_namespace(ctx.client_id)
	local bufnr = vim.api.nvim_get_current_buf()
	vim.diagnostic.reset(ns, bufnr)
	return true
end

for server_name, settings in pairs(servers) do
	local opts = {
		capabilities = capabilities,
		on_attach = on_attach,
		settings = settings,
		handlers = handlers,
	}
	local ok, s = pcall(require, "liu.lsp." .. server_name)
	if ok then
		opts = vim.tbl_deep_extend("force", opts, s)
	end

	require("lspconfig")[server_name].setup(opts)
end
