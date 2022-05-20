-- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md
-- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTIN_CONFIG.md
local null_ls = require("null-ls")

local b = null_ls.builtins

-- local with_root_file = function(...)
--   local files = { ... }
--   return function(utils)
--     return utils.root_has_file(files)
--   end
-- end

local sources = {
  -- b.formatting.stylua.with({
  --   condition = with_root_file("stylua.toml"),
  -- }),
  -- b.formatting.goimports,

  b.diagnostics.golangci_lint,

  b.code_actions.gitsigns,
}

null_ls.setup({ sources = sources })


-- local methods = require("null-ls.methods")
-- local DIAGNOSTICS_ON_SAVE = methods.internal.DIAGNOSTICS_ON_SAVE
-- local golangci_lint = {
--   method = DIAGNOSTICS_ON_SAVE,
--   filetypes = { "go" },
--   generator = null_ls.generator({
--     command = "golangci-lint",
--     to_stdin = true,
--     from_stderr = false,
--     args = {
--       "run",
--       "--fix=false",
--       "--fast",
--       "--out-format=json",
--       "$DIRNAME",
--       "--path-prefix",
--       "$ROOT",
--     },
--     format = "json",
--     check_exit_code = function(code)
--       return code <= 2
--     end,
--     on_output = function(params)
--       local diags = {}
--       for _, d in ipairs(params.output.Issues) do
--         if d.Pos.Filename == params.bufname then
--           table.insert(diags, {
--             row = d.Pos.Line,
--             col = d.Pos.Column,
--             message = d.Text,
--           })
--         end
--       end
--       return diags
--     end,
--   }),
-- }
-- -- add to other sources or register individually
-- null_ls.register(golangci_lint)
