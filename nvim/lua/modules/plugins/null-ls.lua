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

  b.formatting.mdformat,
  b.diagnostics.golangci_lint,
}

null_ls.setup({ sources = sources })

local methods = require("null-ls.methods")
local CODE_ACTION = methods.internal.CODE_ACTION
local git_sign = {
  method = CODE_ACTION,
  filetypes = {},
  generator = {
    fn = function(params)
      local ok, gitsigns_actions = pcall(require("gitsigns").get_actions)
      if not ok or not gitsigns_actions then
        return
      end

      local name_to_title = function(name)
        return name:sub(1, 1):upper() .. name:gsub("_", " "):sub(2)
      end

      local actions = {}
      for name, action in pairs(gitsigns_actions) do
        -- I do not need the blame line action
        if name ~= "blame_line" then
          table.insert(actions, {
            title = name_to_title(name),
            action = function()
              vim.api.nvim_buf_call(params.bufnr, action)
            end,
          })
        end
      end
      return actions
    end,
  },
}
null_ls.register(git_sign)

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
