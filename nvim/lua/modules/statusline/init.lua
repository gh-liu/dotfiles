local api = vim.api

local mode = require("modules.statusline.mode")
local file = require("modules.statusline.file")
local git = require("modules.statusline.git")
local lsp = require("modules.statusline.lsp")

local function set_color()
  -- mode color
  vim.cmd([[hi StatuslineNormalAccent guibg=#d75f5f gui=bold guifg=#e9e9e9]])
  vim.cmd([[hi StatuslineInsertAccent guifg=#e9e9e9 gui=bold guibg=#dab997]])
  vim.cmd([[hi StatuslineReplaceAccent guifg=#e9e9e9 gui=bold guibg=#afaf00]])
  vim.cmd([[hi StatuslineConfirmAccent guifg=#e9e9e9 gui=bold guibg=#83adad]])
  vim.cmd([[hi StatuslineTerminalAccent guifg=#e9e9e9 gui=bold guibg=#6f6f6f]])
  vim.cmd([[hi StatuslineMiscAccent guifg=#e9e9e9 gui=bold guibg=#f485dd]])

  -- file modified color
  vim.cmd(
    [[hi StatuslineFilenameModified guifg=#d75f5f gui=bold guibg=#3a3a3a]]
  )
  vim.cmd([[hi StatuslineFilenameNoMod guifg=#e9e9e9 gui=bold guibg=#3a3a3a]])

  vim.cmd([[hi StatuslineFiletype guibg=#3a3a3a gui=none guifg=#e9e9e9]])

  vim.cmd([[hi StatuslineSeparator guifg=#3a3a3a gui=none guibg=none]])

  vim.cmd([[hi StatuslinePercentage guibg=#3a3a3a gui=none guifg=#dab997]])
  vim.cmd([[hi StatuslineNormal guibg=#3a3a3a gui=none guifg=#e9e9e9]])
  vim.cmd([[hi StatuslineLineCol guibg=#3a3a3a gui=none guifg=#878787]])

  -- lsp diagnostic color
  vim.cmd([[hi StatuslineDiagnosticErrors guibg=#3a3a3a gui=none guifg=Red]])
  vim.cmd(
    [[hi StatuslineDiagnosticWarnings guibg=#3a3a3a gui=none guifg=Orange]]
  )
  vim.cmd(
    [[hi StatuslineDiagnosticInfo guibg=#3a3a3a gui=none guifg=LightBlue]]
  )
  vim.cmd(
    [[hi StatuslineDiagnosticHints guibg=#3a3a3a gui=none guifg=LightGrey]]
  )
  vim.cmd(
    [[hi StatuslineDiagnosticClient guibg=#3a3a3a gui=none guifg=skyblue]]
  )

  -- git color
  vim.cmd([[hi StatuslineGitAdded guibg=#3a3a3a gui=none guifg=green]])
  vim.cmd([[hi StatuslineGitChanged guibg=#3a3a3a gui=none guifg=orange]])
  vim.cmd([[hi StatuslineGitRemoved guibg=#3a3a3a gui=none guifg=red]])
  vim.cmd([[hi StatuslineGitBranch guibg=#3a3a3a gui=none guifg=#f44d27]])
end

set_color()

api.nvim_create_autocmd("ColorScheme", { callback = set_color })

local statuslines = {}
function _G.statusline()
  -- local is_curwin = vim.api.nvim_get_current_win() == tonumber(vim.g.actual_curwin)
  local mod = vim.api.nvim_get_mode().mode
  local mode_name = mode.get_name(mod)
  local mode_color = mode.get_color(mod)
  local mode_str = string.format("%%#%s# %s ", mode_color, mode_name)

  local buf_nr, fname = file.file_nr_name()
  local ftype = ""
  local fencoding = ""
  local line_col_segment = ""
  local fformat = ""
  if fname ~= "" then
    local filetype, filetypeicon = file.file_type()
    -- local filetype = [[%y]]

    fencoding = string.format(
      "%%#%s# %s ",
      "StatuslineLineCol",
      file.file_encoding()
    )
    fformat = string.format(
      "%%#%s# %s ",
      "StatuslineLineCol",
      file.file_format()
    )
    ftype = string.format("%%#%s# %s ", "StatuslineFiletype", filetype)
    line_col_segment = string.format(
      "%%#%s# %s %%#%s# %s %%#%s# %s ",
      "StatuslineLineCol",
      [[|]],
      "StatuslineLineCol",
      [[%l:%c]],
      "StatuslinePercentage",
      [[%P]]
    )
  end

  local file_str = file.get_info()

  local is_paste = vim.o.paste and "PASTE " or ""
  local paste_str = string.format("%%#%s#%s ", "StatuslineNormal", is_paste)

  local is_file_readonly = [[%r]]

  local win_id = vim.g.statusline_winid
  if win_id == vim.api.nvim_get_current_win() or statuslines[win_id] == nil then
    -- mode fileinfo(buf_nr,bufname,set_modified_symbol) git    lsp encode filetype line_col_segment
    local lsp_str = ""
    if lsp.is_lsp_attached() then
      local client, clientsign = lsp.lsp_client_names()
      local cur_errors, all_errors, errorssign = lsp.diagnostic_errors()
      local cur_warnings, all_warnings, warningssign = lsp.diagnostic_warnings()
      local cur_info, all_info, infosign = lsp.diagnostic_info()
      local cur_hints, all_hints, hintssign = lsp.diagnostic_hints()

      local function contact(current, all)
        local sep = "/"
        if all == 0 then
          return string.format("%s", all)
        end
        return string.format("%s%s%s", current, sep, all)
      end

      lsp_str = string.format(
        "%%#%s#%s %%#%s#%s %%#%s#%s %%#%s#%s %%#%s#%s ",
        "StatuslineDiagnosticClient",
        clientsign .. client,
        "StatuslineDiagnosticErrors",
        errorssign .. contact(cur_errors, all_errors),
        "StatuslineDiagnosticWarnings",
        warningssign .. contact(cur_warnings, all_warnings),
        "StatuslineDiagnosticInfo",
        infosign .. contact(cur_info, all_info),
        "StatuslineDiagnosticHints",
        hintssign .. contact(cur_hints, all_hints)
      )
    end

    local git_str = ""
    if true then
      local head, headsign = git.head()
      local added, addedsign = git.added()
      local changed, changedsign = git.changed()
      local removed, removedsign = git.removed()

      local head = head ~= "" and ("[" .. headsign .. head .. "]") or ""
      local added = added ~= "" and (addedsign .. added) or ""
      local changed = changed ~= "" and (changedsign .. changed) or ""
      local removed = removed ~= "" and (removedsign .. removed) or ""

      git_str = string.format(
        "%%#%s#%s%%#%s#%s %%#%s#%s %%#%s#%s",
        "StatuslineGitBranch",
        head,
        "StatuslineGitAdded",
        added,
        "StatuslineGitChanged",
        changed,
        "StatuslineGitRemoved",
        removed
      )
    end

    statuslines[win_id] = mode_str
      .. file_str
      .. is_file_readonly
      .. paste_str
      .. git_str
      .. "%="
      .. lsp_str
      .. fencoding
      .. fformat
      .. ftype
      .. line_col_segment
  else
    -- print(vim.g.statusline_winid, vim.api.nvim_get_current_win())
    statuslines[win_id] = mode_str
      .. file_str
      .. is_file_readonly
      .. paste_str
      .. "%="
      .. fencoding
      .. fformat
      .. ftype
      .. line_col_segment
  end

  return statuslines[win_id]
end

-- StatusLine
vim.o.statusline = "%!v:lua.statusline()"
