
local c = require('nord.palette')

local hl = vim.api.nvim_set_hl
local theme = {}

theme.set_highlights = function()

  -- highlights
  hl(0, "SignColumn", { fg = 'NONE', bg = 'NONE' })
  hl(0, "Conceal", { fg = 'NONE', bg = 'NONE' })
  hl(0, "SpellBad", { fg = 'NONE', bg = 'NONE', sp = c.red, underline=true, })
  hl(0, "SpellCap", { fg = 'NONE', bg = 'NONE', sp = c.blue, underline=true, })
  hl(0, "SpellRare", { fg = 'NONE', bg = 'NONE', sp = c.magenta, underline=true, })
  hl(0, "SpellLocal", { fg = 'NONE', bg = 'NONE', sp = c.cyan, underline=true, })
  hl(0, "Pmenu", { fg = 'NONE', bg = c.magenta })
  hl(0, "PmenuSel", { fg = 'NONE', bg = c.gray })
  hl(0, "PmenuSbar", { fg = 'NONE', bg = c.gray })
  hl(0, "PmenuThumb", { fg = 'NONE', bg = c.white })
  hl(0, "TabLine", { fg = 'NONE', bg = c.gray, underline=true, })
  hl(0, "TabLineSel", { fg = 'NONE', bg = 'NONE', bold=true, })
  hl(0, "TabLineFill", { fg = 'NONE', bg = 'NONE', reverse=true, })
  hl(0, "CursorColumn", { fg = 'NONE', bg = c.yellow })
  hl(0, "CursorLine", { fg = c.gray, bg = 'NONE', underline=true, })
  hl(0, "ColorColumn", { fg = c.red, bg = 'NONE' })
  hl(0, "NormalNC", { fg = 'NONE', bg = 'NONE' })
  hl(0, "MsgArea", { fg = 'NONE', bg = 'NONE',  })
  hl(0, "WinBar", { fg = 'NONE', bg = 'NONE', bold=true, })
  hl(0, "Cursor", { fg = c.bg, bg = c.fg })
  hl(0, "lCursor", { fg = c.bg, bg = c.fg })
  hl(0, "Normal", { fg = 'NONE', bg = 'NONE' })
  hl(0, "FloatShadow", { fg = 'NONE', bg = 'NONE', sp = 'NONE', blend=80,  })
  hl(0, "FloatShadowThrough", { fg = 'NONE', bg = 'NONE', sp = 'NONE', blend=100,  })
  hl(0, "Error", { fg = c.red, bg = 'NONE', bold=true, })
  hl(0, "Todo", { fg = c.yellow, bg = 'NONE', bold=true, })
  hl(0, "Constant", { fg = c.white, bg = 'NONE' })
  hl(0, "Identifier", { fg = c.white, bg = 'NONE' })
  hl(0, "Statement", { fg = c.cyan, bg = 'NONE' })
  hl(0, "PreProc", { fg = c.blue, bg = 'NONE', bold=true, })
  hl(0, "Type", { fg = c.cyan, bg = 'NONE', bold=true, })
  hl(0, "Special", { fg = c.orange, bg = 'NONE' })
  hl(0, "Comment", { fg = c.gray, bg = 'NONE' })
  hl(0, "MatchParen", { fg = 'NONE', bg = c.cyan })
  hl(0, "Ignore", { fg = c.bg, bg = 'NONE' })

  -- diagnostic
  hl(0, "DiagnosticDeprecated", { fg = 'NONE', bg = 'NONE', sp = c.red, strikethrough=true, })
  hl(0, "DiagnosticUnnecessary", { link = 'Comment' })
  hl(0, "DiagnosticError", { fg = c.red, bg = 'NONE' })
  hl(0, "DiagnosticWarn", { fg = c.orange, bg = 'NONE' })
  hl(0, "DiagnosticInfo", { fg = c.blue, bg = 'NONE' })
  hl(0, "DiagnosticHint", { fg = c.gray, bg = 'NONE' })
  hl(0, "DiagnosticOk", { fg = c.green, bg = 'NONE' })
  hl(0, "DiagnosticUnderlineError", { fg = 'NONE', bg = 'NONE', sp = c.red, underline=true, })
  hl(0, "DiagnosticUnderlineWarn", { fg = 'NONE', bg = 'NONE', sp = c.orange, underline=true, })
  hl(0, "DiagnosticUnderlineInfo", { fg = 'NONE', bg = 'NONE', sp = c.blue, underline=true, })
  hl(0, "DiagnosticUnderlineHint", { fg = 'NONE', bg = 'NONE', sp = c.gray, underline=true, })
  hl(0, "DiagnosticUnderlineOk", { fg = 'NONE', bg = 'NONE', sp = c.green, underline=true, })

  -- treesitter
  hl(0, "@text", { link = 'Normal' })

  -- lsp
  hl(0, "@lsp", { link = 'Normal' })
end

return theme