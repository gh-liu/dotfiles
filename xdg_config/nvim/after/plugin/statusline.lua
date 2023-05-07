local ok, _ = pcall(require, "heirline")
if not ok then
	return
end

local conditions = require("heirline.conditions")
local utils = require("heirline.utils")

local function setup_colors()
	return {
		back_ground = "#4C566A",
		fore_ground = "#D8DEE9",
		gray = "#3B4252",
		green = "#A3BE8C",
		blue = "#5E81AC",
		cyan = "#88C0D0",
		red = "#BF616A",
		orange = "#D08770",
		yellow = "#EBCB8B",
		magenta = "#B48EAD",
		-- error = "#BF616A",
		-- warn = "#EBCB8B",
		-- info = "#88C0D0",
		-- hint = "#5E81AC",
	}
end

require("heirline").load_colors(setup_colors())

local dot = "\194\183"
local ViMode = {
	init = function(self)
		self.mode = vim.fn.mode(1)

		if not self.once then
			vim.cmd("au ModeChanged *:*o redrawstatus")
		end
		self.once = true
	end,
	static = {
		mode_names = {
			n = "Normal",
			no = "N" .. dot .. "Operator Pending",
			nov = "N?",
			noV = "N?",
			["no\22"] = "N?",
			niI = "Ni",
			niR = "Nr",
			niV = "Nv",
			nt = "Nt",
			v = "Visual",
			vs = "Vs",
			V = "V" .. dot .. "Line",
			Vs = "Vs",
			["\22"] = "V" .. dot .. "Block",
			["\22s"] = "V" .. dot .. "Block",
			s = "Select",
			S = "S" .. dot .. "Line",
			["\19"] = "S" .. dot .. "Block",
			i = "Insert",
			ic = "Ic",
			ix = "Ix",
			R = "Replace",
			Rc = "Rc",
			Rx = "Rx",
			Rv = "Rv",
			Rvc = "Rv",
			Rvx = "Rv",
			c = "Command",
			cv = "Vim Ex",
			r = "Prompt",
			rm = "More",
			["r?"] = "Confirm",
			["!"] = "Shell",
			t = "Terminal",
		},
		mode_colors = {
			n = "red",
			i = "green",
			v = "cyan",
			V = "cyan",
			["\22"] = "cyan",
			c = "orange",
			s = "purple",
			S = "purple",
			["\19"] = "purple",
			R = "orange",
			r = "orange",
			["!"] = "red",
			t = "red",
		},
	},
	provider = function(self)
		return ("%2(" .. self.mode_names[self.mode] .. "%)")
	end,
	hl = function(self)
		local mode = self.mode:sub(1, 1)
		return { fg = self.mode_colors[mode], bold = true }
	end,
	update = {
		"ModeChanged",
	},
}

local WorkDir = {
	init = function(self)
		self.icon = (vim.fn.haslocaldir(0) == 1 and "l" or "g") .. " " .. " "
		local cwd = vim.fn.getcwd(0)
		self.cwd = vim.fn.fnamemodify(cwd, ":~")
		if not conditions.width_percent_below(#self.cwd, 0.27) then
			self.cwd = vim.fn.pathshorten(self.cwd)
		end
	end,
	hl = { fg = "blue", bold = true },
	flexible = 1,
	{
		provider = function(self)
			local trail = self.cwd:sub(-1) == "/" and "" or "/"
			return self.icon .. self.cwd .. trail .. " "
		end,
	},
	{
		provider = function(self)
			local cwd = vim.fn.pathshorten(self.cwd)
			local trail = self.cwd:sub(-1) == "/" and "" or "/"
			return self.icon .. cwd .. trail .. " "
		end,
	},
	{
		provider = "",
	},
}

local FileNameBlock = {
	init = function(self)
		self.filename = vim.api.nvim_buf_get_name(0)
	end,
}
local FileIcon = {
	init = function(self)
		local filename = self.filename
		local extension = vim.fn.fnamemodify(filename, ":e")
		self.icon, self.icon_color =
			require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })
	end,
	provider = function(self)
		return self.icon and (self.icon .. " ")
	end,
	hl = function(self)
		return { fg = self.icon_color }
	end,
}
local FileName = {
	init = function(self)
		self.lfilename = vim.fn.fnamemodify(self.filename, ":.")
		if self.lfilename == "" then
			self.lfilename = "[No Name]"
		end
	end,
	hl = { fg = utils.get_highlight("Directory").fg },

	flexible = 2,

	{
		provider = function(self)
			return self.lfilename
		end,
	},
	{
		provider = function(self)
			return vim.fn.pathshorten(self.lfilename)
		end,
	},
}
local FileFlags = {
	{
		condition = function()
			return vim.bo.modified
		end,
		provider = "[+]",
		hl = { fg = "green" },
	},
	{
		condition = function()
			return not vim.bo.modifiable or vim.bo.readonly
		end,
		provider = "",
		hl = { fg = "orange" },
	},
}
-- the filename color will change if the buffer is modified.
local FileNameModifer = {
	hl = function()
		if vim.bo.modified then
			-- use `force` because we need to override the child's hl foreground
			return { fg = "cyan", bold = true, force = true }
		end
	end,
}
FileNameBlock =
	utils.insert(FileNameBlock, FileIcon, utils.insert(FileNameModifer, FileName), FileFlags, { provider = "%<" })

local FileType = {
	provider = function()
		return string.upper(vim.bo.filetype)
	end,
	hl = { fg = utils.get_highlight("Type").fg, bold = true },
	-- hl = function()
	-- 	local _, color = require("nvim-web-devicons").get_icon_color_by_filetype(vim.bo.filetype, { default = true })
	-- 	return { fg = color, bold = true }
	-- end,
}

local FileEncoding = {
	provider = function()
		local enc = (vim.bo.fenc ~= "" and vim.bo.fenc) or vim.o.enc -- :h 'enc'
		return enc ~= "utf-8" and enc:upper()
	end,
}
local FileFormat = {
	provider = function()
		local fmt = vim.bo.fileformat
		return fmt ~= "unix" and fmt:upper()
	end,
}

local FileSize = {
	provider = function()
		-- stackoverflow, compute human readable file size
		local suffix = { "b", "k", "M", "G", "T", "P", "E" }
		local fsize = vim.fn.getfsize(vim.api.nvim_buf_get_name(0))
		fsize = (fsize < 0 and 0) or fsize
		if fsize < 1024 then
			return fsize .. suffix[1]
		end
		local i = math.floor((math.log(fsize) / math.log(1024)))
		return string.format("%.2g%s", fsize / math.pow(1024, i), suffix[i + 1])
	end,
}
local FileLastModified = {
	provider = function()
		local ftime = vim.fn.getftime(vim.api.nvim_buf_get_name(0))
		return (ftime > 0) and os.date("%c", ftime)
	end,
}

local Ruler = {
	hl = { fg = "fore_ground" },
	-- %l = current line number
	-- %L = number of lines in the buffer
	-- %c = column number
	-- %P = percentage through file of displayed window
	provider = "%7(%l/%3L%):%2c %P",
}

local ScrollBar = {
	static = {
		sbar = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" },
	},
	provider = function(self)
		local curr_line = vim.api.nvim_win_get_cursor(0)[1]
		local lines = vim.api.nvim_buf_line_count(0)
		local i = math.floor((curr_line - 1) / lines * #self.sbar) + 1
		return string.rep(self.sbar[i], 2)
	end,
	hl = { fg = "blue", bg = "back_ground" },
}

local LSPActive = {
	condition = conditions.lsp_attached,
	update = { "LspAttach", "LspDetach", "BufEnter" },
	provider = function(self)
		local names = {}
		for _, server in pairs(vim.lsp.get_active_clients({ bufnr = 0 })) do
			table.insert(names, server.name)
		end
		return " [" .. table.concat(names, " ") .. "]"
	end,
	hl = { fg = "green", bold = true },
}

local Diagnostics = {
	condition = function()
		return #vim.diagnostic.get(nil) > 0
	end,
	update = { "DiagnosticChanged", "BufEnter" },
	static = {
		error_icon = config.icons.Error,
		warn_icon = config.icons.Warn,
		info_icon = config.icons.Info,
		hint_icon = config.icons.Hint,
	},
	init = function(self)
		self.errors = #vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.ERROR })
		self.warnings = #vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.WARN })
		self.hints = #vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.HINT })
		self.info = #vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.INFO })
	end,
	{
		provider = "![",
	},
	{
		provider = function(self)
			return self.errors > 0 and (self.error_icon .. " " .. self.errors .. " ")
		end,
		hl = { fg = "red", bg = "back_ground" },
	},
	{
		provider = function(self)
			return self.warnings > 0 and (self.warn_icon .. " " .. self.warnings .. " ")
		end,
		hl = { fg = "yellow", bg = "back_ground" },
	},
	{
		provider = function(self)
			return self.info > 0 and (self.info_icon .. " " .. self.info .. " ")
		end,
		hl = { fg = "cyan", bg = "back_ground" },
	},
	{
		provider = function(self)
			return self.hints > 0 and (self.hint_icon .. " " .. self.hints)
		end,
		hl = { fg = "blue", bg = "back_ground" },
	},
	{
		provider = "]",
	},
}

local Git = {
	condition = conditions.is_git_repo,
	init = function(self)
		self.status_dict = vim.b.gitsigns_status_dict
		self.has_changes = self.status_dict.added ~= 0 or self.status_dict.removed ~= 0 or self.status_dict.changed ~= 0
	end,
	hl = { fg = "orange", bg = "back_ground" },
	{
		provider = function(self)
			return " " .. self.status_dict.head
		end,
		hl = { bold = true },
	},
	{
		condition = function(self)
			return self.has_changes
		end,
		provider = "(",
	},
	{
		provider = function(self)
			local count = self.status_dict.added or 0
			return count > 0 and ("+" .. count)
		end,
		hl = { fg = "green", bg = "back_ground" },
	},
	{
		provider = function(self)
			local count = self.status_dict.removed or 0
			return count > 0 and ("-" .. count)
		end,
		hl = { fg = "red", bg = "back_ground" },
	},
	{
		provider = function(self)
			local count = self.status_dict.changed or 0
			return count > 0 and ("~" .. count)
		end,
		hl = { fg = "yellow", bg = "back_ground" },
	},
	{
		condition = function(self)
			return self.has_changes
		end,
		provider = ")",
	},
}

local LeapSign = {
	condition = function()
		return vim.g.user_leap_status == 1
	end,
	{
		provider = function()
			return "Leap->?"
		end,
		hl = "Question",
	},
}

local DAPMessages = {
	condition = function()
		return vim.g.debuging and require("dap").session()
		-- local session = require("dap").session()
		-- return session ~= nil
	end,
	{
		provider = function()
			return config.debug_icons.bug .. " " .. require("dap").status() .. ""
		end,
		hl = "Debug",
	},
}

local TerminalName = {
	provider = function()
		local tname, _ = vim.api.nvim_buf_get_name(0):gsub(".*:", "")
		return " " .. tname
	end,
	hl = { fg = "blue", bold = true },
}

local HelpFilename = {
	condition = function()
		return vim.bo.filetype == "help"
	end,
	provider = function()
		local filename = vim.api.nvim_buf_get_name(0)
		return vim.fn.fnamemodify(filename, ":t")
	end,
	hl = "Directory",
}

local QFName = {
	condition = function()
		return conditions.buffer_matches({
			buftype = {
				"quickfix",
			},
		})
	end,
	FileType,
	{ provider = "%q" },
}

local Align = { provider = "%=" }
local Space = { provider = " " }
local VerticalLine = { provider = "|", hl = { fg = "gray", bg = "back_ground" } }

local DefaultStatusline = {
	ViMode,
	VerticalLine,
	WorkDir,
	FileNameBlock,
	Space,
	{ provider = "%<" },
	Git,
	Align,
	LeapSign,
	Space,
	DAPMessages,
	Space,
	Diagnostics,
	Space,
	LSPActive,
	Space,
	FileType,
	Space,
	Ruler,
	Space,
	ScrollBar,
}

local InactiveStatusline = {
	condition = conditions.is_not_active,
	FileType,
	Space,
	FileName,
	Align,
}

local DapRepl = {
	condition = function()
		return vim.bo.filetype == "dap-repl"
	end,
	hl = { fg = "cyan" },
	FileType,
	Align,
	DAPMessages,
	Space,
	Ruler,
	Space,
	ScrollBar,
}

local HelpFilenameStatusline = {
	condition = function()
		return conditions.buffer_matches({ buftype = { "help" } })
	end,
	hl = { fg = "cyan" },
	FileType,
	Space,
	HelpFilename,
	Align,
}
local QFNameStatusline = {
	condition = function()
		return conditions.buffer_matches({ buftype = { "quickfix" } })
	end,
	hl = { fg = "orange" },
	QFName,
	Align,
}
local TerminalStatusline = {
	condition = function()
		return conditions.buffer_matches({ buftype = { "terminal" } })
	end,
	hl = { fg = "blue" },
	FileType,
	Space,
	TerminalName,
	Align,
}

local SpecialStatusline = {
	condition = function()
		return conditions.buffer_matches({
			buftype = {
				"nofile",
				"prompt",
			},
			filetype = {
				"^git.*",
				"fugitive",
				"harpoon",
			},
		})
	end,
	hl = { fg = "green" },
	FileType,
	Align,
}

local StatusLines = {
	hl = function()
		if conditions.is_active() then
			return "StatusLine"
		else
			return "StatusLineNC"
		end
	end,
	fallthrough = false,
	DapRepl,
	HelpFilenameStatusline,
	QFNameStatusline,
	TerminalStatusline,
	SpecialStatusline,
	InactiveStatusline,
	DefaultStatusline,
}

require("heirline").setup({
	statusline = StatusLines,
})

vim.api.nvim_create_augroup("Heirline", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		local colors = setup_colors()
		utils.on_colorscheme(colors)
	end,
	group = "Heirline",
})
