--- LSP Commands client side
local M = {}

local terminal = require("utils.terminal")

local rust_analyser = function(params)
  -- gh.dump(params)
  local workspace = params.arguments[1].args.workspaceRoot

  local command = vim.tbl_flatten({
    "cargo",
    params.arguments[1].args.cargoArgs,
  })

  if vim.loop.cwd() ~= workspace then
    vim.list_extend(command, { "--manifest-path", workspace .. "/Cargo.toml" })
  end

  if not terminal:is_open() then
    terminal:toggle()
  end

  terminal:send(table.concat(command, " "))
end

M.setup = function()
  -- rust
  -- vim.lsp.commands['rust-analyzer.debugSingle'] = rust_analyser
  vim.lsp.commands["rust-analyzer.runSingle"] = rust_analyser
end

return M
