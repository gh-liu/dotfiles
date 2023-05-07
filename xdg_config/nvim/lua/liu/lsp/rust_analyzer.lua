local M = {}

-- Commands
vim.lsp.commands["rust-analyzer.runSingle"] = function(opts) end
vim.lsp.commands["rust-analyzer.debugSingle"] = function(opts) end
vim.lsp.commands["rust-analyzer.showReferences"] = function(opts) end

M.settings = {
	-- https://rust-analyzer.github.io/manual.html#configuration
	["rust-analyzer"] = {
		checkOnSave = {
			command = "clippy",
		},
		lens = {
			enable = false,
			debug = { enable = false },
			run = { enable = false },
		},
		inlayHints = {
			maxLength = 25,
			closureStyle = "impl_fn",
			renderColons = true,
			bindingModeHints = { enable = false },
			chainingHints = { enable = true },
			closingBraceHints = {
				enable = false,
				minLines = 25,
			},
			closureCaptureHints = { enable = false },
			closureReturnTypeHints = { enable = "never" },
			discriminantHints = { enable = "never" },
			expressionAdjustmentHints = {
				enable = "never",
				hideOutsideUnsafe = false,
				mode = "prefix",
			},
			lifetimeElisionHints = {
				enable = true,
				-- enable = "never",
				useParameterNames = false,
			},
			parameterHints = { enable = true },
			reborrowHints = { enable = "never" },
			typeHints = {
				enable = true,
				hideClosureInitialization = false,
				hideNamedConstructor = false,
			},
		},
	},
}

return M
