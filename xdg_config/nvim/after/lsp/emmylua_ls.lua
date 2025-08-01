-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#emmylua_ls
-- @need-install: cargo install emmylua_ls
return {
	-- https://github.com/EmmyLuaLs/emmylua-analyzer-rust/blob/main/docs/config/emmyrc_json_EN.md#-complete-configuration-example
	settings = {
		Lua = {
			workspace = {
				library = {
					"$VIMRUNTIME/lua",
					"$XDG_CONFIG_HOME/nvim/lua",
				},
			},
		},
	},
}
