local M = {}

local gomodify = "gomodifytags"

M.run_cmd = function(args)
  local fname = vim.fn.expand("%")

  local cmd = { gomodify, "-file", fname, "-w" }

  for _, v in ipairs(args) do
    table.insert(cmd, v)
  end

  -- TODO use tree-sitter get struct name
  local struct_name = nil
  if struct_name == nil then
    local startnr = vim.fn.line("'<")
    local endnr = vim.fn.line("'>")
    if startnr == 0 or endnr == 0 then
      return
    end
    table.insert(cmd, "-line")
    local nrstr = string.format("%d,%d", startnr, endnr)
    table.insert(cmd, nrstr)
  else
    table.insert(cmd, "-struct")
    table.insert(cmd, struct_name)
  end

  table.insert(cmd, "-format")
  table.insert(cmd, "json")

  -- print(table.concat(cmd, " "))

  local b = vim.api.nvim_get_current_buf()
  local data = vim.fn.system(cmd)
  -- print(vim.inspect(data))
  local changes = vim.fn.json_decode(data)
  vim.api.nvim_buf_set_lines(
    b,
    changes.start - 1,
    changes["end"],
    true,
    changes.lines
  )
  vim.cmd("w!")
end

M.add = function(...)
  local opts = { "-add-tags" }
  if #{ ... } == 0 then
    table.insert(opts, "json")
  else
    for _, v in ipairs({ ... }) do
      table.insert(opts, v)
    end
  end

  M.run_cmd(opts)
end

M.rm = function(...)
  local opts = { "-remove-tags" }
  if #{ ... } == 0 then
    table.insert(opts, "json")
  else
    for _, v in ipairs({ ... }) do
      table.insert(opts, v)
    end
  end

  M.run_cmd(opts)
end

return M
