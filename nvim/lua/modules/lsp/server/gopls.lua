local util = require("lspconfig.util")

return {
  cmd = { "gopls", "--remote=auto" },
  filetypes = { "go", "gomod", "gotmpl" },
  single_file_support = true,
  root_dir = util.root_pattern("go.work", "go.mod", ".git"),
  settings = {
    -- more settings: https://github.com/golang/tools/blob/master/gopls/doc/settings.md
    gopls = {
      gofumpt = true,
      staticcheck = true,
      analyses = { unusedwrite = true },
      hints = {
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
      },
    },
  },
  -- init_options = {
  --   usePlaceholders = true,
  -- },
}
