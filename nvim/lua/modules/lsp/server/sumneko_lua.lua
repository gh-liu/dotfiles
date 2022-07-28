local settings = {
  settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = "LuaJIT",
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = { "vim", "gh" },
      },
      workspace = {
        -- Make the server aware of Neovim runtime files
        -- library = vim.api.nvim_get_runtime_file("", true),
        library = os.getenv("HOME")
            .. "/.local/share/nvim/site/pack/packer/start/emmylua-nvim",
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
      },
    },
  },
}

-- local ok, luadev = pcall(require, "lua-dev")
-- if ok then
--   local luadevconf = luadev.setup({
--     lspconfig = {
--       settings = settings,
--     },
--   })
--   settings = luadevconf
-- end

return settings
