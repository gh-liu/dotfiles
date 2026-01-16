vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
	vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.o.termguicolors = true
vim.g.colors_name = "nord"

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

-- terminal colors
M.set_terminal_colors = function()
	vim.g.terminal_color_0 = M.palette.nord1 -- black
	vim.g.terminal_color_1 = M.palette.nord11 -- red
	vim.g.terminal_color_2 = M.palette.nord14 -- green
	vim.g.terminal_color_3 = M.palette.nord13 -- yellow
	vim.g.terminal_color_4 = M.palette.nord9 -- blue
	vim.g.terminal_color_5 = M.palette.nord15 -- magenta
	vim.g.terminal_color_6 = M.palette.nord8 -- cyan
	vim.g.terminal_color_7 = M.palette.nord5 -- white
	vim.g.terminal_color_8 = M.palette.nord3 -- bright black
	vim.g.terminal_color_9 = M.palette.nord11 -- bright red
	vim.g.terminal_color_10 = M.palette.nord14 -- bright green
	vim.g.terminal_color_11 = M.palette.nord13 -- bright yellow
	vim.g.terminal_color_12 = M.palette.nord9 -- bright blue
	vim.g.terminal_color_13 = M.palette.nord15 -- bright magenta
	vim.g.terminal_color_14 = M.palette.nord7 -- bright cyan
	vim.g.terminal_color_15 = M.palette.nord6 -- bright white
end

local hl = vim.api.nvim_set_hl
local c = M.colors

M.set_highlights = function()
	local merge = function(target, source)
		for group, opts in pairs(source) do
			target[group] = opts
		end
	end

	local highlights = {}
	local groups = {
		-- default groups
		base = {
			Underlined = { underline = true, sp = c.gray }, -- text that stands out, HTML links

			Normal = { bg = c.bg, fg = c.fg },
			NormalNC = { fg = c.darkwhite, bg = c.bg }, -- not current window
			NormalFloat = { link = "Normal" }, -- normal text in floating windows
		},
		ui = {
			-- // UI
			NonText = { fg = c.brightergray },
			Conceal = { fg = c.gray },
			Whitespace = { link = "NonText" },
			EndOfBuffer = { link = "NonText" },
		},
		diff = {
			Added = { fg = c.green },
			Changed = { fg = c.yellow },
			Removed = { fg = c.red },
			-- diff
			-- linewise diff
			DiffAdd = { fg = c.green, bg = c.brightgray },
			DiffChange = { fg = c.yellow, bg = c.brightgray },
			DiffDelete = { fg = c.red, bg = c.brightgray },
			-- inline(chawise) diff
			DiffText = { fg = c.blue, bg = c.brightergray, bold = true },
			DiffTextAdd = { fg = c.green, bg = c.brightergray, bold = true },
		},
		float = {
			-- float window
			FloatBorder = { fg = c.gray },
			FloatTitle = { link = "Title" },
			FloatFooter = { link = "Title" },
			FloatShadow = { fg = c.gray, blend = 80 },
			FloatShadowThrough = { fg = c.gray, blend = 100 },
		},
		bars = {
			-- window bar
			WinBar = { bold = true },
			WinBarNC = { link = "WinBar" },
			-- statusline
			StatusLine = { fg = c.darkwhite, bg = c.gray },
			StatusLineNC = { fg = c.brightergray, bg = c.bg },
			-- StatusLineTerm = { link = "PmenuShadow" },
			StatusLineTerm = { fg = c.fg, bg = c.blue },
			-- tabline
			TabLine = { fg = c.brightergray, bg = c.gray },
			TabLineSel = { fg = c.gray, bg = c.lightgreen },
			TabLineFill = { fg = c.brightergray },
		},
		cursor = {
			-- cursor
			Cursor = { fg = c.bg, bg = c.fg },
			lCursor = { link = "Cursor" },
			CursorLine = { bg = c.gray },
			CursorLineNr = { fg = c.lightblue },
			CursorLineSign = { link = "SignColumn" },
			CursorLineFold = { fg = c.brightgray, bold = true },
			TermCursor = { fg = c.fg, bg = c.gray },
			TermCursorNC = { fg = c.fg, bg = c.gray },
		},
		msg = {
			-- msg
			ErrorMsg = { fg = c.red },
			WarningMsg = { fg = c.yellow },
			MoreMsg = { fg = c.orange },
			ModeMsg = { fg = c.green, bold = true },
			MsgArea = { fg = c.fg },
			MsgSeparator = { link = "WinSeparator" },
		},
		fold = {
			-- fold
			Folded = { fg = c.brightgray },
			FoldColumn = { link = "Folded" },
		},
		column = {
			-- column
			SignColumn = { link = "Normal" },
			CursorColumn = { link = "CursorLine" },
			ColorColumn = { link = "CursorLine" },
		},
		lineno = {
			-- line nr
			LineNr = { fg = c.gray },
			-- LineNrAbove = { link = "LineNr" },
			-- LineNrBelow = { link = "LineNr" },
		},
		search = {
			-- search & substitute
			Search = { fg = c.bg, bg = c.lightblue },
			-- IncSearch = { link = "Search" },
			CurSearch = { bg = c.yellow },
			-- Substitute = { link = "Search" },
		},
		visual = {
			-- visual
			Visual = { bg = c.gray },
			VisualNOS = { bg = c.gray },
		},
		pmenu = {
			-- pmenu
			Pmenu = { fg = c.fg, bg = c.gray },
			PmenuSel = { fg = c.fg, bg = c.brightgray },
			PmenuThumb = { fg = c.fg, bg = c.brightergray },
			PmenuSbar = { bg = c.brightergray },
			PmenuBorder = { fg = c.gray, bg = c.gray },
			PmenuShadow = { link = "FloatShadow" },
			PmenuShadowThrough = { link = "FloatShadowThrough" },
			PmenuKind = { link = "Pmenu" },
			PmenuKindSel = { link = "PmenuSel" },
			PmenuExtra = { link = "Pmenu" },
			PmenuExtraSel = { link = "PmenuSel" },
			PmenuMatch = { fg = c.yellow, bold = true },
			PmenuMatchSel = { fg = c.yellow, bg = c.brightgray, bold = true },
		},
		spell = {
			-- spell
			SpellBad = { fg = c.red, undercurl = true },
			SpellCap = { fg = c.lightgreen, undercurl = true },
			SpellLocal = { fg = c.cyan, undercurl = true },
			SpellRare = { fg = c.lightgreen, undercurl = true },
		},
		redraw = {
			-- redraw debug
			RedrawDebugNormal = { reverse = true },
			RedrawDebugClear = { fg = c.yellow },
			RedrawDebugComposed = { fg = c.green },
			RedrawDebugRecompose = { fg = c.red },
		},
		misc = {
			-- misc
			Question = { fg = c.green, bold = true },
			QuickFixLine = { fg = c.cyan, bold = true },
			QuickFixLineNr = { fg = c.darkwhite },
			qfLineNr = { link = "QuickFixLineNr" },

			Title = { fg = c.magenta, bold = true },
			WinSeparator = { fg = c.gray },
			VertSplit = { link = "WinSeparator" },
			Todo = { fg = c.orange, bold = true, italic = true }, -- anything that needs extra attention; mostly the keywords TODO FIXME and XXX
			SpecialKey = { fg = c.lightgreen },
			MatchParen = { underline = true, italic = true, bold = true },
			Directory = { fg = c.lightgreen }, -- directory names (and other special names in listings)
		},
		syntax = {
			-- // Syntax
			Constant = { fg = c.darkwhite }, -- any constant
			Operator = { fg = c.lightblue }, -- "sizeof", "+", "*", etc.
			PreProc = { fg = c.blue }, -- generic Preprocessor
			Type = { fg = c.lightgreen }, -- int, long, char, etc.
			Delimiter = { fg = c.lightblue }, -- character that needs attention like , or .
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
			-- Tag = { link = "Special" }, -- you can use CTRL-] on this
			-- SpecialChar = { link = "Special" }, -- special character in a constant
			-- SpecialComment = { link = "Special" }, -- special character in a constant
			Debug = { fg = c.orange }, -- debugging statements
			Ignore = { fg = c.gray },
			-- LspInlayHint = {link = "NonText"},
			-------------------------------------
			Identifier = { fg = c.fg },
			Function = { fg = c.cyan },
			-- Statement = { bold = true },
			Special = { fg = c.yellow },
			Error = { underline = true, sp = c.red },
			Comment = { fg = c.brightergray, italic = true }, -- italic comments
			String = { fg = c.green },
			-- }}}
		},
		snippet = {
			SnippetTabstop = { link = "Visual" },
			SnippetTabstopActive = { link = "Search" },
		},
		termdebug = {
			-- termdebug
			debugPC = { link = "Debug" },
			debugBreakpoint = { link = "Debug" },
		},
		diagnostic = {
			-- Diagnostic {{{
			DiagnosticError = { fg = c.red },
			DiagnosticWarn = { fg = c.orange },
			DiagnosticInfo = { fg = c.cyan },
			DiagnosticHint = { fg = c.blue },
			DiagnosticOk = { fg = c.green },
			DiagnosticDeprecated = { strikethrough = true, sp = c.red },
			-- DiagnosticUnnecessary = { link = "Comment" },
			DiagnosticUnderlineError = { underline = true, sp = c.red },
			DiagnosticUnderlineWarn = { underline = true, sp = c.orange },
			DiagnosticUnderlineInfo = { underline = true, sp = c.cyan },
			DiagnosticUnderlineHint = { underline = true, sp = c.blue },
			DiagnosticUnderlineOk = { underline = true, sp = c.green },
			-- DiagnosticFloatingError = { link = "DiagnosticError" },
			-- DiagnosticFloatingHint = { link = "DiagnosticHint" },
			-- DiagnosticFloatingInfo = { link = "DiagnosticInfo" },
			-- DiagnosticFloatingOk = { link = "DiagnosticOk" },
			-- DiagnosticFloatingWarn = { link = "DiagnosticWarn" },
			-- DiagnosticSignError = { link = "DiagnosticError" },
			-- DiagnosticSignHint = { link = "DiagnosticHint" },
			-- DiagnosticSignInfo = { link = "DiagnosticInfo" },
			-- DiagnosticSignOk = { link = "DiagnosticOk" },
			-- DiagnosticSignWarn = { link = "DiagnosticWarn" },
			-- DiagnosticVirtualTextError = { link = "DiagnosticError" },
			-- DiagnosticVirtualTextHint = { link = "DiagnosticHint" },
			-- DiagnosticVirtualTextInfo = { link = "DiagnosticInfo" },
			-- DiagnosticVirtualTextOk = { link = "DiagnosticOk" },
			-- DiagnosticVirtualTextWarn = { link = "DiagnosticWarn" },
			-- }}}
		},
		lsp = {
			-- Lsp {{{
			-- semantic-highlight{{{
			-- :h lsp-semantic-highlight
			-- https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_semanticTokens
			-- build in
			["@lsp"] = {},
			["@lsp.type.string"] = {},
			-- ["@lsp.type.class"] = { link = "@type" },
			-- ["@lsp.type.comment"] = { link = "@comment" },
			-- ["@lsp.type.decorator"] = { link = "@attribute" },
			-- ["@lsp.type.enum"] = { link = "@type" },
			-- ["@lsp.type.enumMember"] = { link = "@constant" },
			-- ["@lsp.type.function"] = { link = "@function" },
			-- ["@lsp.type.interface"] = { link = "@type" },
			-- ["@lsp.type.macro"] = { link = "@constant.macro" },
			-- ["@lsp.type.method"] = { link = "@function.method" },
			-- ["@lsp.type.namespace"] = { link = "@module" },
			-- ["@lsp.type.parameter"] = { link = "@variable.parameter" },
			-- ["@lsp.type.property"] = { link = "@property" },
			-- ["@lsp.type.struct"] = { link = "@type" },
			-- ["@lsp.type.type"] = { link = "@type" },
			-- ["@lsp.type.typeParameter"] = { link = "@type.definition" },
			-- ["@lsp.type.variable"] = { link = "@variable" },

			-- user defined
			["@lsp.type.comment"] = {},
			["@lsp.type.keyword"] = { link = "@keyword" },
			["@lsp.mod.readonly"] = { link = "@constant.builtin" },
			["@lsp.mod.deprecated"] = { link = "DiagnosticDeprecated" },
			-- }}}
		},
		lsp_highlight = {
			-- lsp-highlight {{{
			-- :h lsp-highlight
			-- reference
			LspReferenceText = { bg = c.brightgray, italic = true },
			LspReferenceRead = { bg = c.brightgray, bold = true },
			LspReferenceWrite = { bg = c.brightgray, italic = true, bold = true },

			-- inlayhint
			-- LspInlayHint = {link = "NonText"},
			LspInlayHint = { fg = c.brightgray },

			-- codelens
			LspCodeLens = { fg = c.brightergray, bold = true, italic = true },
			LspCodeLensSeparator = { link = "WinSeparator" },

			-- signature active parameter
			LspSignatureActiveParameter = { fg = c.green, bold = true },
			-- }}}
			-- }}}
		},
		treesitter = {
			-- Treesitter {{{
			-- :h treesitter-highlight
			-- build in
			-- ["@variable"] = {},
			-- ["@variable.builtin"] = { link = "Special" },
			-- ["@variable.parameter"] = { link = "Identifier" },
			-- ["@variable.member"] = { link = "Identifier" },
			-- ["@constant"] = { link = "Constant" },
			-- ["@constant.builtin"] = { link = "Special" },
			-- ["@constant.macro"] = { link = "Define" },
			-- ["@module"] = { link = "Structure" },
			-- ["@label"] = { link = "Label" },
			-- ["@string"] = { link = "String" },
			-- ["@string.regexp"] = { link = "SpecialChar" },
			-- ["@string.escape"] = { link = "SpecialChar" },
			-- ["@string.special"] = { link = "SpecialChar" },
			-- ["@string.special.symbol"] = { link = "Constant" },
			-- ["@string.special.url"] = { link = "Underlined" },
			-- ["@character"] = { link = "Character" },
			-- ["@character.special"] = { link = "SpecialChar" },
			-- ["@boolean"] = { link = "Boolean" },
			-- ["@number"] = { link = "Number" },
			-- ["@number.float"] = { link = "Float" },
			-- ["@type"] = { link = "Type" },
			-- ["@type.builtin"] = { link = "Special" },
			-- ["@type.definition"] = { link = "Typedef" },
			-- ["@type.qualifier"] = { link = "StorageClass" },
			-- ["@attribute"] = { link = "Macro" },
			-- ["@property"] = { link = "Identifier" },
			-- ["@function"] = { link = "Function" },
			-- ["@function.builtin"] = { link = "Special" },
			-- ["@function.macro"] = { link = "Macro" },
			["@constructor"] = { link = "Type" },
			-- ["@operator"] = { link = "Operator" },
			-- ["@keyword"] = { link = "Keyword" },
			-- ["@keyword.function"] = { link = "Statement" },
			-- ["@keyword.operator"] = { link = "Operator" },
			-- ["@keyword.import"] = { link = "Include" },
			-- ["@keyword.storage"] = { link = "StorageClass" },
			-- ["@keyword.repeat"] = { link = "Repeat" },
			-- ["@keyword.debug"] = { link = "Debug" },
			-- ["@keyword.exception"] = { link = "Exception" },
			-- ["@keyword.conditional"] = { link = "Conditional" },
			-- ["@keyword.directive"] = { link = "PreProc" },
			-- ["@keyword.directive.define"] = { link = "Define" },
			-- ["@punctuation"] = {},
			-- ["@punctuation.delimiter"] = { link = "Delimiter" },
			-- ["@punctuation.bracket"] = { link = "Delimiter" },
			-- ["@punctuation.special"] = { link = "Special" },
			-- ["@comment"] = { link = "Comment" },
			-- ["@comment.error"] = { link = "DiagnosticError" },
			-- ["@comment.warning"] = { link = "DiagnosticWarn" },
			-- ["@comment.note"] = { link = "DiagnosticInfo" },
			-- ["@comment.todo"] = { link = "Todo" },

			-- ["@markup.strong"] = { bold = true },
			-- ["@markup.italic"] = { italic = true },
			-- ["@markup.strikethrough"] = { strikethrough = true },
			-- ["@markup.underline"] = { underline = true },
			-- ["@markup"] = { link = "Special" }, -- fallback for subgroups; never used itself
			-- ["@markup.heading"] = { link = "Title" },
			-- ["@markup.environment"] = { link = "Structure" },
			-- ["@markup.link"] = { link = "Underlined" },
			-- ["@markup.list.checked"] = { link = "DiagnosticOk" },
			-- ["@markup.list.unchecked"] = { link = "DiagnosticWarn" },

			-- ["@diff.plus"] = { link = "Added" },
			-- ["@diff.minus"] = { link = "Removed" },
			-- ["@diff.delta"] = { link = "Changed" },
			-- ["@tag"] = { link = "Tag" },
			-- ["@tag.delimiter"] = { link = "Delimiter" },
			-- user defined
			["@variable"] = { link = "Identifier" },
			["@module"] = { link = "Include" },
			["@keyword.function"] = { link = "Function" },
			-- }}}
		},
		plugins = {
			-- mini.icons
			MiniIconsAzure = { fg = c.cyan },
			MiniIconsBlue = { fg = c.blue },
			MiniIconsCyan = { fg = c.lightgreen },
			MiniIconsGreen = { fg = c.green },
			MiniIconsGrey = { fg = c.brightergray },
			MiniIconsOrange = { fg = c.orange },
			MiniIconsPurple = { fg = c.magenta },
			MiniIconsRed = { fg = c.red },
			MiniIconsYellow = { fg = c.yellow },

			-- mini.files
			MiniFilesBorder = { link = "FloatBorder" },
			MiniFilesBorderModified = { fg = c.orange },
			MiniFilesCursorLine = { link = "CursorLine" },
			MiniFilesDirectory = { link = "Directory" },
			MiniFilesFile = { link = "Normal" },
			MiniFilesNormal = { link = "NormalFloat" },
			MiniFilesTitle = { link = "Title" },
			MiniFilesTitleFocused = { fg = c.yellow, bold = true },

			-- tiny-glimmer.nvim
			TinyGlimmerPaste = { bg = c.blue },
			TinyGlimmerRedo = { bg = c.green },
			TinyGlimmerUndo = { bg = c.red },

			-- fold-line.nvim
			FoldLine = { link = "Folded" },
			FoldLineCurrent = { link = "WinSeparator" },

			-- vim-fugitive
			diffAdded = { link = "DiffAdd" },
			diffRemoved = { link = "DiffDelete" },
			StatusLineFugitive = { fg = c.lightgreen, bg = c.brightgray },

			-- mini.diff
			MiniDiffOverAdd = { fg = c.green, bg = c.brightergray },
			MiniDiffOverChange = { fg = c.yellow, bg = c.brightergray },
			MiniDiffOverChangeBuf = { fg = c.yellow, bg = c.brightergray },
			MiniDiffOverContext = { fg = c.darkwhite },
			MiniDiffOverContextBuf = { fg = c.darkwhite },
			MiniDiffOverDelete = { fg = c.red, bg = c.brightergray },

			-- vim-flog
			flogBranch1 = { fg = c.blue },
			flogBranch2 = { fg = c.green },
			flogBranch3 = { fg = c.yellow },
			flogBranch4 = { fg = c.orange },
			flogBranch5 = { fg = c.red },
			flogBranch6 = { fg = c.magenta },
			flogBranch7 = { fg = c.cyan },
			flogBranch8 = { fg = c.lightblue },
			flogHash = { fg = c.lightblue },
			flogAuthor = { fg = c.green },
			flogDate = { fg = c.brightgray },
			flogRef = { fg = c.cyan },
			flogRefTag = { fg = c.orange },
			flogRefRemote = { fg = c.blue },
			flogRefHead = { fg = c.yellow },
			flogRefHeadArrow = { fg = c.yellow },
			flogRefHeadBranch = { fg = c.green },

			-- nvim-dap
			DapBreakpoint = { fg = c.red },
			DapBreakpointCondition = { fg = c.yellow },
			DapLogPoint = { fg = c.blue },
			DapStopped = { fg = c.green },
			DapBreakpointRejected = { fg = c.brightergray },

			-- rainbow-delimiters.nvim
			RainbowDelimiterRed = { fg = c.red },
			RainbowDelimiterYellow = { fg = c.yellow },
			RainbowDelimiterBlue = { fg = c.blue },
			RainbowDelimiterOrange = { fg = c.orange },
			RainbowDelimiterGreen = { fg = c.green },
			RainbowDelimiterViolet = { fg = c.magenta },
			RainbowDelimiterCyan = { fg = c.cyan },

			-- snacks.nvim
			SnacksNormal = { link = "NormalFloat" },
			SnacksNormalNC = { link = "NormalFloat" },
			SnacksWinBar = { link = "WinBar" },
			SnacksWinBarNC = { link = "WinBarNC" },
			SnacksTitle = { link = "Title" },
			SnacksFooter = { link = "Title" },
			SnacksWinSeparator = { link = "WinSeparator" },
			SnacksGhNormal = { link = "NormalFloat" },
			SnacksGhNormalFloat = { link = "NormalFloat" },
			SnacksGhBorder = { link = "FloatBorder" },
			SnacksGhTitle = { link = "Title" },
			SnacksGhFooter = { link = "Title" },
			SnacksIndent = { fg = c.brightergray },
			SnacksIndent1 = { fg = c.blue },
			SnacksIndent2 = { fg = c.cyan },
			SnacksIndent3 = { fg = c.green },
			SnacksIndent4 = { fg = c.yellow },
			SnacksIndent5 = { fg = c.orange },
			SnacksIndent6 = { fg = c.red },
			SnacksIndent7 = { fg = c.magenta },
			SnacksIndent8 = { fg = c.lightblue },
			SnacksIndentScope = { fg = c.lightblue },
			SnacksIndentChunk = { fg = c.brightgray },
			SnacksNotifierHistory = { link = "NormalFloat" },
			SnacksDashboardNormal = { link = "Normal" },
			SnacksDashboardIcon = { fg = c.cyan },
			SnacksDashboardDesc = { fg = c.darkwhite },
			SnacksDashboardKey = { fg = c.lightblue },
			SnacksInputNormal = { link = "NormalFloat" },
			SnacksInputBorder = { link = "FloatBorder" },
			SnacksInputTitle = { link = "Title" },
			SnacksInputIcon = { fg = c.yellow },

			-- lspconfig
			LspInfoList = { link = "Function" },
			LspInfoTip = { link = "Comment" },
			LspInfoTitle = { link = "Title" },
			LspInfoFiletype = { link = "Type" },
			LspInfoBorder = { link = "FloatBorder" },
		},
	}

	for _, section in pairs(groups) do
		merge(highlights, section)
	end

	for group, opts in pairs(highlights) do
		hl(0, group, opts)
	end
end

M.set_terminal_colors()
M.set_highlights()
