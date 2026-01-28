-- vim.wo.foldlevel = 1
-- vim.wo.foldenable = false

local function change_headings(direction)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
  local level = #(line:match("^#+") or "")

  if level == 0 then
    vim.notify("Not on a heading", vim.log.levels.WARN)
    return
  end

  -- Find next heading with same or lower level
  local end_row = vim.api.nvim_buf_line_count(0) + 1
  for i = row + 1, vim.api.nvim_buf_line_count(0) do
    local l = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    local h = l:match("^#+")
    if h and #h <= level then
      end_row = i
      break
    end
  end

  -- Modify all headings in section (current + deeper)
  local lines = vim.api.nvim_buf_get_lines(0, row - 1, end_row, false)
  for i, l in ipairs(lines) do
    local h = l:match("^#+")
    if h then
      local new_level = math.max(1, math.min(6, #h + direction))
      lines[i] = string.rep("#", new_level) .. l:sub(#h + 1)
    end
  end
  vim.api.nvim_buf_set_lines(0, row - 1, end_row, false, lines)
end

local function complete_direction(arglead)
  local candidates = { "-", "+" }
  return vim.tbl_filter(function(c)
    return vim.startswith(c, arglead)
  end, candidates)
end

vim.api.nvim_create_user_command("MDHead", function(opts)
  local arg = opts.args:gsub("^%s+|%s+$", "")
  local direction
  if arg == "-" or arg == "" then
    direction = -1
  elseif arg == "+" then
    direction = 1
  else
    direction = tonumber(arg)
  end
  if not direction or direction == 0 then
    vim.notify("Usage: :MDHead - (or + or -N, +N)", vim.log.levels.ERROR)
    return
  end
  change_headings(direction)
end, { nargs = 1, complete = complete_direction })
