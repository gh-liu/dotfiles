local api = vim.api

local M = {}

function M.position()
  local row, col = unpack(api.nvim_win_get_cursor(0))

  -- Turn col from byteindex to column number and make it start from 1
  col = vim.str_utfindex(api.nvim_get_current_line(), col) + 1

  -- return string.format("%3d:%-2d", row, col)
  return string.format("%d:%d", row, col)
end

function M.line_percentage()
  local curr_line = api.nvim_win_get_cursor(0)[1]
  local lines = api.nvim_buf_line_count(0)

  if curr_line == 1 then
    return "Top"
  elseif curr_line == lines then
    return "Bot"
  else
    return string.format("%2d%%%%", math.ceil(curr_line / lines * 99))
  end
end
return M
