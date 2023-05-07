local M = {}

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

M.on_attach = function(client, bufnr)
	vim.api.nvim_buf_create_user_command(bufnr, "GoGet", function(opts)
		vim.lsp.buf.execute_command({
			arguments = { { AddRequire = true, Pkg = opts.fargs[1], URI = vim.uri_from_bufnr(0) } },
			command = "gopls.go_get_package",
		})
	end, {
		nargs = 1,
		desc = "Run go get package",
	})

	vim.api.nvim_buf_create_user_command(bufnr, "GoModTidy", function(opts)
		local wss = vim.lsp.buf.list_workspace_folders()
		vim.lsp.buf.execute_command({
			arguments = {
				{
					URIs = { vim.uri_from_fname(wss[1] .. "/go.mod") },
				},
			},
			command = "gopls.tidy",
		})
	end, {
		nargs = 0,
		desc = "Run go mod tidy",
	})

	vim.api.nvim_buf_create_user_command(bufnr, "GoOrganizeImports", function(opts)
		vim.lsp.buf.code_action({
			context = { only = { "source.organizeImports" } },
			apply = true,
			async = false,
		})
	end, {
		nargs = 0,
		desc = "organize go imports",
	})
end

M.settings = {
	-- https://github.com/golang/tools/blob/master/gopls/doc/settings.md
	gopls = {
		analyses = {
			nilness = true,
			shadow = true,
			unusedparams = true,
			unusewrites = true,
		},
		codelenses = {
			test = false,
		},
		hints = {
			assignVariableTypes = true,
			compositeLiteralFields = true,
			constantValues = true,
			functionTypeParameters = true,
			parameterNames = true,
			rangeVariableTypes = true,
		},
		gofumpt = true,
		staticcheck = true,
		semanticTokens = true,
		usePlaceholders = false,
		buildFlags = { "-tags", "debug" },
	},
}

return M
