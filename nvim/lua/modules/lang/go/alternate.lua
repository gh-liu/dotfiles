local M = {}
function M.switch(bang, cmd)
  -- get current buffer name
  local current_file = vim.fn.expand("%")
  if #current_file <= 1 then
    vim.notify("no buffer name", vim.lsp.log_levels.ERROR)
    return
  end

  -- get alertnate file name
  local prefix = ""
  local alt_file = ""

  local is_go_file = false
  if not is_go_file then
    local s, e = string.find(current_file, "_test%.go$")
    if s ~= nil then
      prefix = vim.fn.split(current_file, "_test.go")[1]
      alt_file = prefix .. ".go"
      is_go_file = true
    end
  end

  if not is_go_file then
    local s, e = string.find(current_file, "%.go$")
    if s ~= nil then
      prefix = vim.fn.split(current_file, ".go")[1]
      alt_file = prefix .. "_test.go"
      is_go_file = true
    end
  end

  if not is_go_file then
    vim.notify(current_file .. " is not a go file", vim.lsp.log_levels.ERROR)
    return
  end

  -- open alternate file
  if
    vim.fn.filereadable(alt_file) == 0
    and vim.fn.bufexists(alt_file) == 0
    and not bang
  then
    vim.notify("couldn't find " .. alt_file, vim.lsp.log_levels.ERROR)
    return
  else
    local open_cmd = ""
    if #cmd <= 1 then
      open_cmd = "e " .. alt_file
    else
      open_cmd = cmd .. " " .. alt_file
    end
    vim.cmd(open_cmd)
  end
end

return M
