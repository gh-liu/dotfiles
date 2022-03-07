-- https://github.com/b0o/SchemaStore.nvim
return {
  settings = {
    json = {
      schemas = {
        {
          fileMatch = { "*.golangci.json" },
          url = "https://json.schemastore.org/golangci-lint.json",
        },
      },
    },
  },
}
