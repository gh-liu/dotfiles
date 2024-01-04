local M = {}

M.palette = {
	nord0 = "#2E3440",
	nord1 = "#3B4252",
	nord2 = "#434C5E",
	nord3 = "#4C566A",

	nord4 = "#D8DEE9",
	nord5 = "#E5E9F0",
	nord6 = "#ECEFF4",

	nord7 = "#8FBCBB",
	nord8 = "#88C0D0",
	nord9 = "#81A1C1",
	nord10 = "#5E81AC",

	nord11 = "#BF616A",
	nord12 = "#D08770",
	nord13 = "#EBCB8B",
	nord14 = "#A3BE8C",
	nord15 = "#B48EAD",
}

M.colors = {
	fg = M.palette.nord4,
	bg = M.palette.nord0,

	red = M.palette.nord11,
	green = M.palette.nord14,
	blue = M.palette.nord10,
	yellow = M.palette.nord13,

	cyan = M.palette.nord8,
	orange = M.palette.nord12,
	magenta = M.palette.nord15,

	lightgreen = M.palette.nord7,
	lightblue = M.palette.nord9,

	white = M.palette.nord6,
	darkwhite = M.palette.nord5,
	darkerwhite = M.palette.nord4,

	black = M.palette.nord0,
	gray = M.palette.nord1,
	brightgray = M.palette.nord2,
	brightergray = M.palette.nord3,
}

M.setup = function(opts)
	vim.cmd("hi clear")

	vim.o.background = "dark"
	if vim.fn.exists("syntax_on") then
		vim.cmd("syntax reset")
	end

	vim.o.termguicolors = true
	vim.g.colors_name = "nord"

	M.set_highlights()
end

local hl = vim.api.nvim_set_hl
local c = M.colors

-- Base on: src/nvim/highlight_group.c
M.set_highlights = function()
	local highlights = {
		NONE = {},
		Bold = { bold = true },
		Underlined = { underline = true, sp = c.gray }, -- text that stands out, HTML links

		Constant = { fg = c.darkwhite }, -- any constant
		Operator = { fg = c.lightblue }, -- "sizeof", "+", "*", etc.
		PreProc = { fg = c.blue }, -- generic Preprocessor
		Type = { fg = c.lightgreen }, -- int, long, char, etc.
		Delimiter = { fg = c.lightblue }, -- character that needs attention like , or .

		-- UI
		NonText = { fg = c.brightgray, bold = true },
		-- normal text
		Normal = { bg = c.bg, fg = c.fg },
		-- NormalNC = {}, -- not current window
		NormalFloat = { link = "Normal" }, -- normal text in floating windows
		-- cursor
		Cursor = { fg = c.bg, bg = c.fg },
		lCursor = { link = "Cursor" },
		CursorLine = { bg = c.gray },
		CursorLineNr = { fg = c.yellow },
		-- CursorLineSign = { link = "SignColumn" },
		-- CursorLineFold = { link = "FoldColumn" },
		TermCursor = { fg = c.fg, bg = c.gray },
		TermCursorNC = { fg = c.fg, bg = c.gray },
		-- line nr
		LineNr = { fg = c.gray },
		-- LineNrAbove = { link = "LineNr" },
		-- LineNrBelow = { link = "LineNr" },
		-- column
		SignColumn = { link = "Normal" },
		CursorColumn = { link = "CursorLine" },
		-- ColorColumn = {},
		-- fold
		Folded = { fg = c.brightgray, italic = true },
		FoldColumn = { link = "NonText" },
		-- tabline
		TabLine = { fg = c.brightergray, bg = c.gray },
		TabLineSel = { fg = c.gray, bg = c.lightgreen },
		TabLineFill = { fg = c.brightergray },
		-- window bar
		WinBar = { bold = true },
		WinBarNC = { link = "WinBar" },
		VertSplit = { fg = c.blue },
		WinSeparator = { link = "VertSplit" },
		-- statusline
		StatusLine = { fg = c.fg, bg = c.brightergray },
		StatusLineNC = { fg = c.fg, bg = c.gray },
		-- msg
		ErrorMsg = { fg = c.red },
		WarningMsg = { fg = c.yellow },
		MoreMsg = { fg = c.green },
		ModeMsg = { fg = c.green, bold = true },
		-- MsgArea = {},
		-- MsgSeparator = { link = "WinSeparator" },
		-- diff
		DiffAdd = { fg = c.green, bg = c.gray }, -- diff mode: Added line
		DiffChange = { fg = c.yellow, bg = c.gray }, --  diff mode: Changed line
		DiffDelete = { fg = c.red, bg = c.gray }, -- diff mode: Deleted line
		DiffText = { fg = c.blue, bg = c.gray }, -- diff mode: Changed text within a changed line
		-- spell
		SpellBad = { fg = c.red, italic = true, undercurl = true },
		SpellCap = { fg = c.lightgreen, italic = true, undercurl = true },
		SpellLocal = { fg = c.cyan, italic = true, undercurl = true },
		SpellRare = { fg = c.lightgreen, italic = true, undercurl = true },
		-- float windows
		FloatBorder = { fg = c.blue },
		-- FloatTitle = { link = "Title" },
		-- FloatFooter = { link = "Title" },
		-- FloatShadow = { fg = c.gray, blend = 80 },
		-- FloatShadowThrough = { fg = c.gray, blend = 100 },
		-- pmenu
		Pmenu = { fg = c.blue, bg = c.bg },
		PmenuSel = { fg = c.fg, bg = c.blue },
		PmenuThumb = { fg = c.fg, bg = c.brightergray },
		-- PmenuSbar = { fg = c.fg, bg = c.brightergray, bold = true },
		-- search & substitute
		Search = { fg = c.white, bg = c.blue },
		-- IncSearch = { link = "Search" },
		CurSearch = { bg = c.yellow },
		-- Substitute = { link = "Search" },
		-- visual
		Visual = { bg = c.brightgray },
		VisualNOS = { bg = c.brightgray },

		-- syntax(both)
		-- Character = { link = "Constant" },
		Number = { fg = c.magenta },
		Boolean = { fg = c.lightgreen },
		-- Float = { link = "Number" },
		Conditional = { link = "Keyword" }, -- normal if, then, else, endif, switch, etc.
		Repeat = { link = "Conditional" }, -- normal any other keyword
		Label = { fg = c.lightgreen }, -- case, default, etc.
		Keyword = { fg = c.blue, bold = true }, -- normal for, do, while, etc.
		Exception = { fg = c.red }, -- try, catch, throw
		-- Include = { link = "PreProc" }, -- preprocessor #include
		-- Define = { link = "PreProc" }, -- preprocessor #define
		-- Macro = { link = "PreProc" }, -- same as Define
		-- PreCondit = { link = "PreProc" }, -- same as Define
		-- StorageClass = { link = "Type" }, -- static, register, volatile, etc.
		-- Structure = { link = "Type" }, -- struct, union, enum, etc.
		-- Typedef = { link = "Type" }, -- A typedef
		Tag = { fg = c.lightgreen }, -- you can use CTRL-] on this
		-- SpecialChar = { link = "Special" }, -- special character in a constant
		-- SpecialComment = { link = "Special" }, -- special character in a constant
		Debug = { fg = c.orange }, -- debugging statements
		Ignore = { fg = c.gray }, -- left blank, hidden
		SnippetTabstop = { link = "Visual" }, -- left blank, hidden
		Conceal = { fg = c.gray },
		-- Whitespace = { link = "NonText" },
		-- EndOfBuffer = { link = "NonText" },
		-- redraw debug
		RedrawDebugNormal = { reverse = true },
		RedrawDebugClear = { fg = c.yellow },
		RedrawDebugComposed = { fg = c.green },
		RedrawDebugRecompose = { fg = c.red },
		-- misc
		Todo = { fg = c.orange, bold = true, italic = true }, -- anything that needs extra attention; mostly the keywords TODO FIXME and XXX
		SpecialKey = { fg = c.lightgreen },
		MatchParen = { underline = true, italic = true, bold = true },
		Title = { fg = c.magenta, bold = true },
		WildMenu = { fg = c.yellow, bold = true },
		QuickFixLine = { fg = c.darkwhite },
		Directory = { fg = c.lightgreen }, -- directory names (and other special names in listings)
		Question = { fg = c.green, bold = true },

		-- syntax(dark)
		Comment = { fg = c.brightergray, italic = true }, -- italic comments
		String = { fg = c.green },
		Identifier = { fg = c.fg },
		Function = { fg = c.cyan },
		-- Statement = { bold = true },
		Special = { fg = c.yellow },
		Error = { underline = true, sp = c.red },

		-- Diagnostic
		DiagnosticError = { fg = c.red },
		DiagnosticWarn = { fg = c.orange },
		DiagnosticInfo = { fg = c.cyan },
		DiagnosticHint = { fg = c.blue },
		DiagnosticOk = { fg = c.green },
		DiagnosticUnderlineError = { underline = true, sp = c.red },
		DiagnosticUnderlineWarn = { underline = true, sp = c.orange },
		DiagnosticUnderlineInfo = { underline = true, sp = c.cyan },
		DiagnosticUnderlineHint = { underline = true, sp = c.blue },
		DiagnosticUnderlineOk = { underline = true, sp = c.green },
		DiagnosticDeprecated = { strikethrough = true },
		DiagnosticUnnecessary = { link = "Comment" },

		-- LSP semantic tokens
		-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_semanticTokens
		-- :h lsp-semantic-highlight
		["@lsp"] = {},
		-- default
		-- ["@lsp.type.class"] = { link = "Structure" },
		-- ["@lsp.type.comment"] = { link = "Comment" },
		["@lsp.type.comment"] = {},
		-- ["@lsp.type.decorator"] = { link = "Function" },
		-- ["@lsp.type.enum"] = { link = "Structure" },
		-- ["@lsp.type.enumMember"] = { link = "Constant" },
		-- ["@lsp.type.function"] = { link = "Function" },
		-- ["@lsp.type.interface"] = { link = "Structure" },
		-- ["@lsp.type.macro"] = { link = "Macro" },
		-- ["@lsp.type.method"] = { link = "Function" },
		-- ["@lsp.type.namespace"] = { link = "Structure" },
		["@lsp.type.namespace"] = { link = "Include" },
		-- ["@lsp.type.parameter"] = { link = "Identifier" },
		-- ["@lsp.type.property"] = { link = "Identifier" },
		-- ["@lsp.type.struct"] = { link = "Structure" },
		-- ["@lsp.type.type"] = { link = "Type" },
		-- ["@lsp.type.typeParameter"] = { link = "Typedef" },
		-- ["@lsp.type.variable"] = {}, -- don't highlight to reduce visual overload
		-- user defined
		-- ["@lsp.type.keyword"] = { link = "Keyword" },
		["@lsp.mod.deprecated"] = { link = "DiagnosticDeprecated" },

		-- Lsp reference
		LspReferenceText = { bg = c.brightgray, italic = true },
		LspReferenceRead = { bg = c.brightgray, bold = true },
		LspReferenceWrite = { bg = c.brightgray, italic = true, bold = true },

		-- Lsp inlayhint
		LspInlayHint = { fg = c.brightgray },

		-- Lsp codelens
		LspCodeLens = { fg = c.blue, bold = true },
		-- LspCodeLensText = { link = "LspCodeLens" },
		-- LspCodeLensTextSign = { link = "LspCodeLens" },
		-- LspCodeLensTextSeparator = { link = "WinSeparator" },

		-- Treesitter
		["@text.reference"] = { link = "LspReferenceText" },
	}

	for group, opts in pairs(highlights) do
		hl(0, group, opts)
	end
end

return M
