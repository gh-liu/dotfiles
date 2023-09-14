local c = require('nord.palette')

local hl = vim.api.nvim_set_hl
local theme = {}

theme.set_highlights = function()
  local highlights = {}

  local editor = {
    NONE = {},
    -- syntax
    Comment = { fg = c.gray, italic = true }, -- italic comments
    PreProc = { fg = c.blue },                -- generic Preprocessor
    Type = { fg = c.shadowgreen },            -- int, long, char, etc.
    Constant = { fg = c.foreground },         -- any constant
    Identifier = { fg = c.foreground },       -- any variable name
    Special = { fg = c.yellow },              -- any special symbol
    Statement = { fg = c.cyan },              -- any statement

    Delimiter = { fg = c.shadowgreen },       -- character that needs attention like , or .
    Include = { link = "PreProc" },           -- preprocessor #include
    Define = { link = "PreProc" },            -- preprocessor #define
    Macro = { link = "Define" },              -- same as Define
    Typedef = { link = "Type" },              -- A typedef
    Structure = { fg = c.shadowgreen },       -- struct, union, enum, etc.
    String = { fg = c.green },                -- any string
    Number = { fg = c.magenta },              -- a number constant: 5
    Float = { link = "Number" },              -- a floating point constant: 2.3e10
    Boolean = { fg = c.shadowgreen },         -- a boolean constant: TRUE, false
    Character = { fg = c.shadowgreen },       -- any character constant: 'c', '\n'
    Function = { fg = c.cyan },               -- normal function names -- ts
    StorageClass = { fg = c.shadowgreen },    -- static, register, volatile, etc.
    Keyword = { fg = c.blue, bold = true },   -- normal for, do, while, etc.
    Conditional = { link = "Keyword" },       -- normal if, then, else, endif, switch, etc.
    Repeat = { fg = c.blue },                 -- normal any other keyword
    Label = { fg = c.shadowgreen },           -- case, default, etc.
    Operator = { fg = c.blue },               -- "sizeof", "+", "*", etc.
    Exception = { fg = c.red },               -- try, catch, throw
    SpecialChar = { link = "Special" },       -- special character in a constant
    Tag = { fg = c.shadowgreen },             -- you can use CTRL-] on this
    Debug = { fg = c.orange },                -- debugging statements

    -- eidtor
    Underlined = { underline = true, sp = c.green },      -- text that stands out, HTML links
    Ignore = { fg = c.black },                            -- left blank, hidden
    Todo = { fg = c.orange, bold = true, italic = true }, -- anything that needs extra attention; mostly the keywords TODO FIXME and XXX
    Conceal = { bg = c.background },
    -- diff
    DiffAdd = { fg = c.green, bg = c.black },     -- diff mode: Added line
    DiffChange = { fg = c.yellow, bg = c.black }, --  diff mode: Changed line
    DiffDelete = { fg = c.red, bg = c.black },    -- diff mode: Deleted line
    DiffText = { fg = c.magenta, bg = c.black },  -- diff mode: Changed text within a changed line
    -- spell
    SpellBad = { fg = c.red, italic = true, undercurl = true },
    SpellCap = { fg = c.shadowgreen, italic = true, undercurl = true },
    SpellLocal = { fg = c.cyan, italic = true, undercurl = true },
    SpellRare = { fg = c.shadowgreen, italic = true, undercurl = true },
    -- pmenu
    Pmenu = { fg = c.blue, bg = c.background },
    PmenuSel = { fg = c.foreground, bg = c.blue },
    PmenuSbar = { fg = c.foreground, bg = c.brighterblack, bold = true },
    PmenuThumb = { fg = c.foreground, bg = c.brighterblack },
    -- tabline
    TabLine = { fg = c.brighterblack, bg = c.black },
    TabLineSel = { fg = c.black, bg = c.shadowgreen },
    TabLineFill = { fg = c.brighterblack },
    -- visual
    Visual = { bg = c.brightblack },
    VisualNC = { bg = c.brightblack },
    -- fold
    Folded = { fg = c.shadowgreen, italic = true },
    FoldColumn = { fg = c.shadowgreen },
    -- search&substitute
    Search = { fg = c.brightWhite, bg = c.blue },
    IncSearch = { fg = c.brightWhite, bg = c.blue },
    CurSearch = {},
    -- Substitute = { link = "Search" },
    -- statusline
    StatusLine = { fg = c.foreground, bg = c.brighterblack },
    StatusLineNC = { fg = c.foreground, bg = c.black },
    -- term cursor
    TermCursor = { fg = c.foreground, bg = c.black },
    TermCursorNC = { fg = c.foreground, bg = c.black },
    -- cursor line
    CursorLine = { bg = c.black },
    CursorLineNr = { fg = c.yellow },
    -- CursorLineSign = { link = "SignColumn" },
    -- CursorLineFold = { link = "FoldColumn" },
    -- cursor
    Cursor = { fg = c.foreground, bg = c.background, reverse = true },
    lCursor = { fg = c.foreground, bg = c.background },
    -- line nr
    LineNr = { fg = c.gray },
    -- LineNrAbove = { link = "LineNr" },
    -- LineNrBelow = { link = "LineNr" },
    -- Window bar of current window.
    WinBar = { bold = true },
    -- Window bar of not-current windows.
    -- WinBarNC = { link = "WinBar" },
    -- msg
    ErrorMsg = { fg = c.red },
    WarningMsg = { fg = c.yellow },
    MoreMsg = { fg = c.green },
    ModeMsg = { bold = true },
    -- MsgSeparator = { link = "WinSeparator" },
    MsgArea = {},
    -- redraw
    redrawDebugNormal = { reverse = true },
    redrawDebugClear = { fg = c.yellow },
    redrawDebugComposed = { fg = c.green },
    redrawDebugRecompose = { fg = c.red },
    -- normal text
    Normal = { bg = c.background, fg = c.foreground },
    NormalNC = {}, -- not current window
    -- NormalFloat = { fg = blue }, -- normal text in floating windows
    -- column
    SignColumn = { link = "Normal" },
    CursorColumn = { link = "CursorLine" },
    ColorColumn = {},
    -- misc
    SpecialKey = { fg = c.shadowgreen },
    MatchParen = { underline = true, italic = true, bold = true },
    FloatShadow = { fg = c.black, blend = 80 },
    FloatShadowThrough = { fg = c.black, blend = 100 },
    -- EndOfBuffer = { link = "NonText" },
    Directory = { fg = c.shadowgreen }, -- directory names (and other special names in listings)
    Question = { fg = c.green, bold = true },
    VertSplit = { fg = c.blue },
    -- WinSeparator = { link = "VertSplit" },
    Title = { fg = c.magenta, bold = true },
    WildMenu = { fg = c.yellow, bold = true },
    -- QuickFixLine = { fg = yellow },
    -- Whitespace = { link = "NonText" },
    Error = { fg = c.red, underline = true },

    -- LGH:
    FloatBorder = { fg = c.blue }, -- normal text and background color
    -- FloatTitle = { link = "Title" },
    NonText = { fg = c.brightblack, bold = true },
  }
  highlights = vim.tbl_extend("force", highlights, editor)

  local ts = {
    ["@text"] = {},
    ["@text.literal"] = { link = "Comment" },
    ["@text.reference"] = { link = "Identifier" },
    ["@text.title"] = { link = "Title" },
    ["@text.uri"] = { link = "Underlined" },
    ["@text.underline"] = { link = "Underlined" },
    ["@text.todo"] = { link = "Todo" },
    ["@comment"] = { link = "Comment" },
    ["@punctuation"] = { link = "Delimiter" },
    ["@constant"] = { link = "Constant" },
    ["@constant.builtin"] = { link = "Special" },
    ["@constant.macro"] = { link = "Define" },
    ["@define"] = { link = "Define" },
    ["@macro"] = { link = "Macro" },
    ["@string"] = { link = "String" },
    ["@string.escape"] = { link = "SpecialChar" },
    ["@string.special"] = { link = "SpecialChar" },
    ["@character"] = { link = "Character" },
    ["@character.special"] = { link = "SpecialChar" },
    ["@number"] = { link = "Number" },
    ["@boolean"] = { link = "Boolean" },
    ["@float"] = { link = "Float" },
    ["@function"] = { link = "Function" },
    ["@function.builtin"] = { link = "Special" },
    ["@function.macro"] = { link = "Macro" },
    ["@parameter"] = { link = "Identifier" },
    ["@method"] = { link = "Function" },
    ["@field"] = { link = "Identifier" },
    ["@property"] = { link = "Identifier" },
    ["@constructor"] = { link = "Special" },
    ["@conditional"] = { link = "Conditional" },
    ["@repeat"] = { link = "Repeat" },
    ["@label"] = { link = "Label" },
    ["@operator"] = { link = "Operator" },
    ["@keyword"] = { link = "Keyword" },
    ["@exception"] = { link = "Exception" },
    ["@variable"] = { link = "Identifier" },
    ["@type"] = { link = "Type" },
    ["@type.definition"] = { link = "Typedef" },
    ["@storageclass"] = { link = "StorageClass" },
    ["@namespace"] = { link = "Include" },
    ["@include"] = { link = "Include" },
    ["@preproc"] = { link = "PreProc" },
    ["@debug"] = { link = "Debug" },
    ["@tag"] = { link = "Tag" },
  }
  highlights = vim.tbl_extend("force", highlights, ts)

  local diagnostic = {
    DiagnosticError = { fg = c.red },
    DiagnosticWarn = { fg = c.orange },
    DiagnosticInfo = { fg = c.blue },
    DiagnosticHint = { fg = c.gray },
    DiagnosticOk = { fg = c.green },
    DiagnosticUnderlineError = { underline = true, sp = c.red },
    DiagnosticUnderlineWarn = { underline = true, sp = c.orange },
    DiagnosticUnderlineInfo = { underline = true, sp = c.blue },
    DiagnosticUnderlineHint = { underline = true, sp = c.gray },
    DiagnosticUnderlineOk = { underline = true, sp = c.green },
    DiagnosticVirtualTextError = { link = "DiagnosticError" },
    DiagnosticVirtualTextWarn = { link = "DiagnosticWarn" },
    DiagnosticVirtualTextInfo = { link = "DiagnosticInfo" },
    DiagnosticVirtualTextHint = { link = "DiagnosticHint" },
    DiagnosticVirtualTextOk = { link = "DiagnosticOk" },
    DiagnosticFloatingError = { link = "DiagnosticError" },
    DiagnosticFloatingWarn = { link = "DiagnosticWarn" },
    DiagnosticFloatingInfo = { link = "DiagnosticInfo" },
    DiagnosticFloatingHint = { link = "DiagnosticHint" },
    DiagnosticFloatingOk = { link = "DiagnosticOk" },
    DiagnosticSignError = { link = "DiagnosticError" },
    DiagnosticSignWarn = { link = "DiagnosticWarn" },
    DiagnosticSignInfo = { link = "DiagnosticInfo" },
    DiagnosticSignHint = { link = "DiagnosticHint" },
    DiagnosticSignOk = { link = "DiagnosticOk" },
    DiagnosticDeprecated = { strikethrough = true, sp = c.red },
    DiagnosticUnnecessary = { link = "Comment" },
  }
  highlights = vim.tbl_extend("force", highlights, diagnostic)

  local lsp = {
    -- LspReferenceText = { reverse = true },
    LspReferenceText = { fg = c.foreground, bg = c.gray },
    LspReferenceRead = { link = "LspReferenceText" },
    LspReferenceWrite = { link = "LspReferenceText" },
    -- lsp inlayhint
    LspInlayHint = { fg = c.brightblack },
    -- lsp codelens
    LspCodeLens = { link = "DiagnosticInfo" },
    LspCodeLensText = { link = "DiagnosticSignInfo" },
    LspCodeLensTextSign = { link = "DiagnosticSignInfo" },
    LspCodeLensTextSeparator = { link = "WinSeparator" },
    -- sem token
    ["@lsp"] = {},
    ["@lsp.type.class"] = { link = "Structure" },
    ["@lsp.type.comment"] = {},
    ["@lsp.type.decorator"] = { link = "Function" },
    ["@lsp.type.enum"] = { link = "Structure" },
    ["@lsp.type.enumMember"] = { link = "Constant" },
    ["@lsp.type.function"] = { link = "Function" },
    ["@lsp.type.interface"] = { link = "Structure" },
    ["@lsp.type.macro"] = { link = "Macro" },
    ["@lsp.type.method"] = { link = "Function" },
    ["@lsp.type.namespace"] = { link = "Include" },
    ["@lsp.type.parameter"] = { link = "Identifier" },
    ["@lsp.type.property"] = { link = "Identifier" },
    ["@lsp.type.struct"] = { link = "Structure" },
    ["@lsp.type.type"] = { link = "Type" },
    ["@lsp.type.typeParameter"] = { link = "Typedef" },
    ["@lsp.type.variable"] = { link = "Identifier" },

    -- LGH:
    -- ["@lsp.mod.defaultLibrary"] = { link = "Special" },
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "Special" },
    -- ["@lsp.typemod.enumMember.defaultLibrary"] = { link = "Special" },
    ["@lsp.type.keyword"] = { link = "Keyword" },
  }
  highlights = vim.tbl_extend("force", highlights, lsp)

  for group, opts in pairs(highlights) do
    hl(0, group, opts)
  end
end

return theme
