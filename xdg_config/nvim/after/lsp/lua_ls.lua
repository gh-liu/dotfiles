-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md#lua_ls
-- Download from https://github.com/LuaLS/lua-language-server/releases
return {
	-- https://github.com/LuaLS/lua-language-server/wiki/Settings
	settings = {
		Lua = {
			hint = {
				enable = true,
				arrayIndex = "Disable",
			},
			format = { enable = false }, -- instead of using stylua
			telemetry = { enable = false },
			workspace = {
				library = { "$VIMRUNTIME/lua" },
			},
			completion = {
				-- https://github.com/LuaLS/lua-language-server/wiki/Settings#completioncallsnippet
				callSnippet = "Replace",
			},
		},
	},
	---@param client vim.lsp.Client
	on_init = function(client) end,
}
