-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#zls
-- Download from https://github.com/zigtools/zls/releases
return {
	-- https://github.com/zigtools/zls#configuration-options
	settings = {
		zls = {
			enable_inlay_hints = true,
			inlay_hints_show_variable_type_hints = true,
			inlay_hints_show_parameter_name = true,
			inlay_hints_show_builtin = true,
			inlay_hints_exclude_single_argument = false,
			inlay_hints_hide_redundant_param_names = true,
			inlay_hints_hide_redundant_param_names_last_token = true,
			enable_autofix = false,
			warn_style = true,
		},
	},
}
