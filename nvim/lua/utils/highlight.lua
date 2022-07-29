local M = {}

local TERMGUICOLORS = vim.o.termguicolors

---Get highlight properties for a given highlight name
---@param name string
---@return table
function M.get_highlight(name)
  local hl = vim.api.nvim_get_hl_by_name(name, TERMGUICOLORS)
  if TERMGUICOLORS then
    hl.fg = hl.foreground
    hl.bg = hl.background
    hl.sp = hl.special
    hl.foreground = nil
    hl.backgroung = nil
    hl.special = nil
  else
    hl.ctermfg = hl.foreground
    hl.ctermbg = hl.background
    hl.foreground = nil
    hl.backgroung = nil
    hl.special = nil
  end
  return hl
end

return M
