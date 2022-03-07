local M = {}

-- mode name
local mode_table = {
  n = "Normal",
  no = "N·Operator Pending",
  v = "Visual",
  V = "V·Line",
  ["^V"] = "V·Block",
  s = "Select",
  S = "S·Line",
  ["^S"] = "S·Block",
  i = "Insert",
  ic = "Insert",
  R = "Replace",
  Rv = "V·Replace",
  c = "Command",
  cv = "Vim Ex",
  ce = "Ex",
  r = "Prompt",
  rm = "More",
  ["r?"] = "Confirm",
  ["!"] = "Shell",
  t = "Terminal",
}

function M.get_name(mode)
  return string.upper(mode_table[mode] or "V-Block")
end

function M.get_color(mode)
  local mode_color = "StatuslineMiscAccent"
  if mode == "n" then
    mode_color = "StatuslineNormalAccent"
  elseif mode == "i" or mode == "ic" then
    mode_color = "StatuslineInsertAccent"
  elseif mode == "R" then
    mode_color = "StatuslineReplaceAccent"
  elseif mode == "c" then
    mode_color = "StatuslineConfirmAccent"
  elseif mode == "t" then
    mode_color = "StatuslineTerminalAccent"
  else
    mode_color = "StatuslineMiscAccent"
  end

  return mode_color
end

return M
