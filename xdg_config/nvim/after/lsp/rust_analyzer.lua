-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#rust_analyzer
-- rustup component add rust-analyzer
return {
	-- https://rust-analyzer.github.io/book/configuration.html
	settings = {
		["rust-analyzer"] = {
			checkOnSave = true,
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
			completion = {
				callable = {
					snippets = "fill_arguments",
				},
			},
		},
	},
}
