vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
	vim.cmd("syntax reset")
end

vim.g.colors_name = "nord"

vim.o.background = "dark"
vim.o.termguicolors = true

-- https://www.nordtheme.com/docs/colors-and-palettes
local palettes = {
	-- Polar Night
	nord0 = "#2E3440",
	nord1 = "#3B4252", -- lighter than nord0
	nord2 = "#434C5E", -- lighter than nord1
	nord3 = "#4C566A", -- lighter than nord2
	nord3_bright = "#616E88", -- out of palettes
	-- Snow Storm
	nord4 = "#D8DEE9",
	nord5 = "#E5E9F0", -- lighter than nord4
	nord6 = "#ECEFF4", -- lighter than nord5
	-- Frost
	nord7 = "#8FBCBB",
	nord8 = "#88C0D0", -- darker than nord7
	nord9 = "#81A1C1", -- darker than nord8
	nord10 = "#5E81AC", -- darker than nord9
	-- Aurora
	nord11 = "#BF616A", -- red
	nord12 = "#D08770", -- orange
	nord13 = "#EBCB8B", -- yellow
	nord14 = "#A3BE8C", -- green
	nord15 = "#B48EAD", -- purple
}

-- Neovim Terminal Colors
vim.g.terminal_color_0 = palettes.nord1
vim.g.terminal_color_1 = palettes.nord11
vim.g.terminal_color_2 = palettes.nord14
vim.g.terminal_color_3 = palettes.nord13
vim.g.terminal_color_4 = palettes.nord9
vim.g.terminal_color_5 = palettes.nord15
vim.g.terminal_color_6 = palettes.nord8
vim.g.terminal_color_7 = palettes.nord5
vim.g.terminal_color_8 = palettes.nord3
vim.g.terminal_color_9 = palettes.nord11
vim.g.terminal_color_10 = palettes.nord14
vim.g.terminal_color_11 = palettes.nord13
vim.g.terminal_color_12 = palettes.nord9
vim.g.terminal_color_13 = palettes.nord15
vim.g.terminal_color_14 = palettes.nord7
vim.g.terminal_color_15 = palettes.nord6

-- named color
local background = palettes.nord0
local foreground = palettes.nord4

local black = palettes.nord1
local brightblack = palettes.nord2
local brighterblack = palettes.nord3

local gray = palettes.nord3_bright

local white = palettes.nord5
local brightWhite = palettes.nord6

local shadowgreen = palettes.nord7
local cyan = palettes.nord8
-- local blue = palettes.nord9
local blue = palettes.nord10

local red = palettes.nord11
local orange = palettes.nord12
local yellow = palettes.nord13
local green = palettes.nord14
local purple = palettes.nord15

local red_draken = "#662a2f"
local green_draken = "#51693c"
local yellow_draken = "#9f731c"

-- type
local line = black
local selection = brightblack
local window = brighterblack
local border = blue

--- lighten or darken a hex color
---@param color
---@param percent
---@return
local function shadeColor(color, percent)
	local num = tonumber(string.sub(color, 2), 16)
	local r = bit.rshift(num, 16) + percent
	local b = bit.band(bit.rshift(num, 8), 0x00FF) + percent
	local g = bit.band(num, 0x0000FF) + percent
	local newColor = bit.bor(g, bit.bor(bit.lshift(b, 8), bit.lshift(r, 16)))
	return string.format("#%x", newColor)
end

local highlights = {}

local editor = {
	NONE = {},
	-- syntax
	Comment = { fg = gray, italic = true }, -- italic comments
	PreProc = { fg = blue }, -- generic Preprocessor
	Type = { fg = shadowgreen }, -- int, long, char, etc.
	Constant = { fg = foreground }, -- any constant
	Identifier = { fg = foreground }, -- any variable name
	Special = { fg = yellow }, -- any special symbol
	Statement = { fg = cyan }, -- any statement

	Delimiter = { fg = shadowgreen }, -- character that needs attention like , or .
	Include = { link = "PreProc" }, -- preprocessor #include
	Define = { link = "PreProc" }, -- preprocessor #define
	Macro = { link = "Define" }, -- same as Define
	Typedef = { link = "Type" }, -- A typedef
	Structure = { fg = shadowgreen }, -- struct, union, enum, etc.
	String = { fg = green }, -- any string
	Number = { fg = purple }, -- a number constant: 5
	Float = { link = "Number" }, -- a floating point constant: 2.3e10
	Boolean = { fg = shadowgreen }, -- a boolean constant: TRUE, false
	Character = { fg = shadowgreen }, -- any character constant: 'c', '\n'
	Function = { fg = cyan }, -- normal function names -- ts
	StorageClass = { fg = shadowgreen }, -- static, register, volatile, etc.
	Keyword = { fg = blue, bold = true }, -- normal for, do, while, etc.
	Conditional = { link = "Keyword" }, -- normal if, then, else, endif, switch, etc.
	Repeat = { fg = blue }, -- normal any other keyword
	Label = { fg = shadowgreen }, -- case, default, etc.
	Operator = { fg = blue }, -- "sizeof", "+", "*", etc.
	Exception = { fg = red }, -- try, catch, throw
	SpecialChar = { link = "Special" }, -- special character in a constant
	Tag = { fg = shadowgreen }, -- you can use CTRL-] on this
	Debug = { fg = orange }, -- debugging statements

	-- eidtor
	Underlined = { underline = true, sp = green }, -- text that stands out, HTML links
	Ignore = { fg = line }, -- left blank, hidden
	Todo = { fg = orange, bold = true, italic = true }, -- anything that needs extra attention; mostly the keywords TODO FIXME and XXX
	Conceal = { bg = background },
	-- diff
	DiffAdd = { fg = green, bg = line }, -- diff mode: Added line
	DiffChange = { fg = yellow, bg = line }, --  diff mode: Changed line
	DiffDelete = { fg = red, bg = line }, -- diff mode: Deleted line
	DiffText = { fg = purple, bg = line }, -- diff mode: Changed text within a changed line
	-- spell
	SpellBad = { fg = red, italic = true, undercurl = true },
	SpellCap = { fg = shadowgreen, italic = true, undercurl = true },
	SpellLocal = { fg = cyan, italic = true, undercurl = true },
	SpellRare = { fg = shadowgreen, italic = true, undercurl = true },
	-- pmenu
	Pmenu = { fg = blue, bg = background },
	PmenuSel = { fg = foreground, bg = blue },
	PmenuSbar = { fg = foreground, bg = window, bold = true },
	PmenuThumb = { fg = foreground, bg = window },
	-- tabline
	TabLine = { fg = window, bg = line },
	TabLineSel = { fg = line, bg = shadowgreen },
	TabLineFill = { fg = window },
	-- visual
	Visual = { bg = selection },
	VisualNC = { bg = selection },
	-- fold
	Folded = { fg = shadowgreen, italic = true },
	FoldColumn = { fg = shadowgreen },
	-- search&substitute
	Search = { fg = brightWhite, bg = blue },
	IncSearch = { fg = brightWhite, bg = blue },
	CurSearch = {},
	-- Substitute = { link = "Search" },
	-- statusline
	StatusLine = { fg = foreground, bg = window },
	StatusLineNC = { fg = foreground, bg = line },
	-- term cursor
	TermCursor = { fg = foreground, bg = line },
	TermCursorNC = { fg = foreground, bg = line },
	-- cursor line
	CursorLine = { bg = line },
	CursorLineNr = { fg = yellow },
	-- CursorLineSign = { link = "SignColumn" },
	-- CursorLineFold = { link = "FoldColumn" },
	-- cursor
	Cursor = { fg = foreground, bg = background, reverse = true },
	lCursor = { fg = foreground, bg = background },
	-- line nr
	LineNr = { fg = gray },
	-- LineNrAbove = { link = "LineNr" },
	-- LineNrBelow = { link = "LineNr" },
	-- Window bar of current window.
	WinBar = { bold = true },
	-- Window bar of not-current windows.
	-- WinBarNC = { link = "WinBar" },
	-- msg
	ErrorMsg = { fg = red },
	WarningMsg = { fg = yellow },
	MoreMsg = { fg = green },
	ModeMsg = { bold = true },
	-- MsgSeparator = { link = "WinSeparator" },
	MsgArea = {},
	-- redraw
	redrawDebugNormal = { reverse = true },
	redrawDebugClear = { fg = yellow },
	redrawDebugComposed = { fg = green },
	redrawDebugRecompose = { fg = red },
	-- normal text
	Normal = { bg = background, fg = foreground },
	NormalNC = {}, -- not current window
	-- NormalFloat = { fg = blue }, -- normal text in floating windows
	-- column
	SignColumn = { link = "Normal" },
	CursorColumn = { link = "CursorLine" },
	ColorColumn = {},
	-- misc
	SpecialKey = { fg = shadowgreen },
	MatchParen = { underline = true, italic = true, bold = true },
	FloatShadow = { fg = line, blend = 80 },
	FloatShadowThrough = { fg = line, blend = 100 },
	-- EndOfBuffer = { link = "NonText" },
	Directory = { fg = shadowgreen }, -- directory names (and other special names in listings)
	Question = { fg = green, bold = true },
	VertSplit = { fg = border },
	-- WinSeparator = { link = "VertSplit" },
	Title = { fg = purple, bold = true },
	WildMenu = { fg = yellow, bold = true },
	-- QuickFixLine = { fg = yellow },
	-- Whitespace = { link = "NonText" },
	Error = { fg = red, underline = true },

	-- LGH:
	FloatBorder = { fg = border }, -- normal text and background color
	-- FloatTitle = { link = "Title" },
	NonText = { fg = selection, bold = true },
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
	DiagnosticError = { fg = red },
	DiagnosticWarn = { fg = orange },
	DiagnosticInfo = { fg = blue },
	DiagnosticHint = { fg = gray },
	DiagnosticOk = { fg = green },
	DiagnosticUnderlineError = { underline = true, sp = red },
	DiagnosticUnderlineWarn = { underline = true, sp = orange },
	DiagnosticUnderlineInfo = { underline = true, sp = blue },
	DiagnosticUnderlineHint = { underline = true, sp = gray },
	DiagnosticUnderlineOk = { underline = true, sp = green },
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
	DiagnosticDeprecated = { strikethrough = true, sp = red },
	DiagnosticUnnecessary = { link = "Comment" },
}
highlights = vim.tbl_extend("force", highlights, diagnostic)

local lsp = {
	LspReferenceText = { bg = gray },
	LspReferenceRead = { link = "LspReferenceText" },
	LspReferenceWrite = { link = "LspReferenceText" },
	-- lsp inlayhint
	LspInlayHint = { fg = brightblack },
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

local nvim_set_hl = vim.api.nvim_set_hl
for group, opts in pairs(highlights) do
	nvim_set_hl(0, group, opts)
end
