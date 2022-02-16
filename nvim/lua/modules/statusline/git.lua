local M = {}

function M.vcs()
  local branch_sign = ""

  local git_info = vim.b.gitsigns_status_dict
  if not git_info or git_info.head == "" then
    return ""
  end

  local added = git_info.added > 0 and ("+" .. git_info.added .. " ") or ""

  local changed = git_info.changed > 0 and ("~" .. git_info.changed .. " ")
    or ""

  local removed = git_info.removed > 0 and ("-" .. git_info.removed .. " ")
    or ""

  local pad = ((added ~= "") or (removed ~= "") or (changed ~= "")) and " "
    or ""

  local diff_str = string.format("%s%s%s%s", added, removed, changed, pad)

  return string.format("%s%s %s ", diff_str, branch_sign, git_info.head)
end

return M
