-- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md
-- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTIN_CONFIG.md
local null_ls = require("null-ls")

local b = null_ls.builtins
local exagit = require("modules.plugins.nullls.code_actions.git")
local exago = require("modules.plugins.nullls.code_actions.go")

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

  b.formatting.mdformat,
  b.formatting.shfmt,
  b.diagnostics.golangci_lint,
  exagit.git_sign,
  exago.gomodifytags,
  exago.gotests,
}

null_ls.setup({ sources = sources })

-- for _, file in ipairs(
--   vim.fn.readdir(
--     vim.fn.stdpath("config") .. "/lua/modules/plugins/nullls/code_actions",
--     [[v:val =~ '\.lua$']]
--   )
-- ) do
--   require("modules.plugins.nullls.code_actions." .. file:gsub("%.lua$", ""))
-- end
