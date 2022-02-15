local M = {}

local cmd = vim.cmd
local fn = vim.fn

M.buf_to_tab = function()
  -- skip if there is only one window open
  if vim.tbl_count(vim.api.nvim_tabpage_list_wins(0)) == 1 then
    print("Cannot expand single buffer")
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  local view = fn.winsaveview()
  -- note: tabedit % does not properly work with terminal buffer
  cmd([[tabedit]])
  -- set buffer and remove one opened by tabedit
  local tabedit_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_delete(tabedit_buf, { force = true })
  -- restore original view
  fn.winrestview(view)
end

return M
