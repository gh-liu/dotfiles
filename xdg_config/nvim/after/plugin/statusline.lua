if false then
	return
end

local api = vim.api
local fn = vim.fn

local icons = config.icons
local colors = config.colors

-- Do not display the command that produced the quickfix list.
-- https://neovim.io/doc/user/filetype.html#ft-qf-plugin
vim.g.qf_disable_statusline = 1

---extract highlight
---@param highlight string
---@return color|nil
local function highlight_colors(highlight)
	if fn.hlexists(highlight) == 0 then
		return nil
	end

	local hl = api.nvim_get_hl(0, { name = highlight })
	local bg = hl.bg and ("#%06x"):format(hl.bg) or nil
	local fg = hl.fg and ("#%06x"):format(hl.fg) or nil
	return { bg = bg, fg = fg }
end

local status_line_bg = highlight_colors("StatusLine").bg

local H = {
	statusline_hls = {}, ---@type table<string, boolean>
}

function H.get_or_create_hl(hl)
	local hl_name = "Statusline" .. hl

	if not H.statusline_hls[hl] then
		local fg = highlight_colors(hl).fg
		api.nvim_set_hl(0, hl_name, { bg = status_line_bg, fg = fg })
		H.statusline_hls[hl] = true
	end

	return hl_name
end

--- @param hl string
--- @param item string
--- @return string
function H.add_highlight(hl, item)
	return "%#" .. hl .. "#" .. item
end

--- @param hl string
--- @param item string
--- @return string
function H.add_highlight2(hl, item)
	return H.add_highlight(H.get_or_create_hl(hl), item)
end

---@param items any[]
---@return string
function H.concat_items(items)
	local result = ""
	for _, item in ipairs(items) do
		result = result .. H.add_highlight2(item.hl, item.text)
	end
	return result
end

---@param item string
---@return string
function H.truncate(item)
	local t = "%<"
	return t .. item
end

---@return string
function H.align()
	return "%="
end

---@param i integer|nil
---@return string
function H.space(i)
	local count = i or 1
	return fn["repeat"](" ", count)
end

local separator_name = "StatuslineSeparator"
api.nvim_set_hl(0, separator_name, { bg = status_line_bg, fg = colors.gray })
---@return string
function H.sep()
	return H.add_highlight(separator_name, "|")
end

local Items = {}

-- :h mode()
-- Note that: \19 = ^S and \22 = ^V.
local mode_to_str = {
	["n"] = "NORMAL",
	["no"] = "OP-PENDING",
	["nov"] = "OP-PENDING",
	["noV"] = "OP-PENDING",
	["no\22"] = "OP-PENDING",
	["niI"] = "NORMAL-I",
	["niR"] = "NORMAL-R",
	["niV"] = "NORMAL-V",
	["nt"] = "NORMAL",
	["ntT"] = "NORMAL",
	["v"] = "VISUAL",
	["vs"] = "VISUAL",
	["V"] = "VISUAL-L",
	["Vs"] = "VISUAL-L",
	["\22"] = "VISUAL-B",
	["\22s"] = "VISUAL-B",
	["s"] = "SELECT",
	["S"] = "SELECT-L",
	["\19"] = "SELECT-B",
	["i"] = "INSERT",
	["ic"] = "INSERT",
	["ix"] = "INSERT",
	["R"] = "REPLACE",
	["Rc"] = "REPLACE",
	["Rx"] = "REPLACE",
	["Rv"] = "VIRT REPLACE",
	["Rvc"] = "VIRT REPLACE",
	["Rvx"] = "VIRT REPLACE",
	["c"] = "COMMAND",
	["cv"] = "VIM EX",
	["ce"] = "EX",
	["r"] = "PROMPT",
	["rm"] = "MORE",
	["r?"] = "CONFIRM",
	["!"] = "SHELL",
	["t"] = "TERMINAL",
}
local mode_colors = {
	ModeNormal = colors.red,
	ModePENDING = colors.magenta,
	ModeVisual = colors.blue,
	ModeInsert = colors.green,
	ModeSELECT = colors.magenta,
	ModeCOMMAND = colors.orange,
	ModeTERMINAL = colors.cyan,
	ModeEX = colors.yellow,
	ModeREPLACE = colors.cyan,
	ModeUNKNOWN = colors.gray,
}
for k, v in pairs(mode_colors) do
	api.nvim_set_hl(0, "Statusline" .. k, { fg = v, bg = status_line_bg, bold = true })
end
Items.mode = function()
	local mode = mode_to_str[api.nvim_get_mode().mode] or "UNKNOWN"

	local hl = "ModeUNKNOWN"
	if mode:find("NORMAL") then
		hl = "ModeNormal"
	elseif mode:find("PENDING") then
		hl = "ModePending"
	elseif mode:find("VISUAL") then
		hl = "ModeVisual"
	elseif mode:find("INSERT") then
		hl = "ModeInsert"
	elseif mode:find("SELECT") then
		hl = "ModeSELECT"
	elseif mode:find("COMMAND") then
		hl = "ModeCommand"
	elseif mode:find("TERMINAL") then
		hl = "ModeTERMINAL"
	elseif mode:find("EX") then
		hl = "ModeEX"
	elseif mode:find("REPLACE") then
		hl = "ModeREPLACE"
	end

	return H.add_highlight("Statusline" .. hl, mode)
end
Items.preview_window = function()
	if vim.wo.previewwindow then
		return "%w"
	else
		return ""
	end
end
Items.diff_window = function()
	if vim.wo.diff then
		return H.add_highlight2("ErrorMsg", "[Diff]")
	else
		return ""
	end
end
Items.work_dir = function()
	local icon = (fn.haslocaldir(0) == 1 and "l" or "g") .. " " .. icons.directory
	local cwd = fn.pathshorten(fn.getcwd(0))
	return H.add_highlight2("Directory", string.format("%s%s/", icon, H.truncate(cwd)))
end
local stages = {
	-- stage number (0 to 3)
	-- [<n>:]<path>
	["0"] = "Index",
	["1"] = "Base", -- Common ancestor
	["2"] = "Ours", -- Target: the branch you're merging into
	["3"] = "Theirs", -- Merged: the branch you're merging from
}
Items.buf_name = function()
	local sep = ":"
	local buf_name = api.nvim_buf_get_name(0)

	local obj_type_hi = "DiffText"
	local obj_id_hi = "Constant"
	if vim.startswith(buf_name, "fugitive://") then
		local object_type = vim.b.fugitive_type and string.format("(%s)", vim.b.fugitive_type) or ""

		local _, _, revision, relpath = buf_name:find([[^fugitive://.*/%.git.*/(%x-)/(.*)]])
		revision = revision or ""
		relpath = relpath or ""
		local relpath_len = #relpath
		if relpath_len == 0 then
			return H.concat_items({
				{ hl = obj_type_hi, text = object_type },
				{ hl = obj_id_hi, text = revision },
				{ hl = "Delimiter", text = ":" }, -- this is a tree
			})
		end

		local revision_len = #revision
		if revision_len == 0 then
			return H.concat_items({
				{ hl = obj_type_hi, text = object_type },
				{ hl = obj_id_hi, text = relpath },
			})
		end

		local stage_str = stages[revision]
		if stage_str then
			stage_str = string.format("[%s %s]", revision, stage_str)
			return H.concat_items({
				{ hl = obj_type_hi, text = object_type },
				{ hl = "Title", text = stage_str },
				{ hl = "Delimiter", text = sep },
				{ hl = "Normal", text = relpath },
			})
		end

		return H.concat_items({
			{ hl = obj_type_hi, text = object_type },
			{ hl = obj_id_hi, text = revision },
			{ hl = "Delimiter", text = sep },
			{ hl = "Normal", text = relpath },
		})
	elseif vim.startswith(buf_name, "gitsigns://") then
		local type_blob = "(blob)"
		local _, _, revision, relpath = buf_name:find([[^gitsigns://.*/%.git.*/(.*):(.*)]])
		-- buf_name = type_blob .. revision .. sep .. relpath
		-- return H.add_highlight2("Normal", buf_name)
		return H.concat_items({
			{ hl = obj_type_hi, text = type_blob },
			{ hl = obj_id_hi, text = revision },
			{ hl = "Delimiter", text = sep },
			{ hl = "Normal", text = relpath },
		})
	else
		buf_name = api.nvim_eval_statusline("%f", {}).str
		return H.add_highlight2("Normal", buf_name)
	end
end
Items.buf_flag = function()
	-- [+][RO]
	-- return H.add_highlight2("ErrorMsg", "%m") .. H.add_highlight2("WarningMsg", "%r")
	return H.concat_items({
		{ hl = "ErrorMsg", text = "%m" },
		{ hl = "WarningMsg", text = "%r" },
	})
end
Items.git = function()
	local head = vim.b.gitsigns_head --or vim.g.gitsigns_head
	if not head then
		return ""
	end
	return H.add_highlight2("DiffText", string.format("%s %s", icons.git, head))
end
Items.dap = function()
	if not package.loaded["dap"] or require("dap").status() == "" then
		return ""
	end
	return H.add_highlight2("Debug", string.format("%s %s", icons.bug, require("dap").status()))
end

Items.diagnostics = function()
	local get_counts = function(buf)
		local acc = {
			ERROR = 0,
			WARN = 0,
			INFO = 0,
			HINT = 0,
		}
		local diag_count = vim.diagnostic.count(buf)
		for level, count in pairs(diag_count) do
			local severity = vim.diagnostic.severity[level]
			acc[severity] = acc[severity] + count
		end
		return acc
	end

	local all_counts = get_counts(nil)
	local local_counts = get_counts(0)
	local parts = {}
	for severity, count in pairs(all_counts) do
		if count > 0 then
			local hl = "Diagnostic" .. severity:sub(1, 1) .. severity:sub(2):lower()
			table.insert(
				parts,
				H.add_highlight2(
					hl,
					string.format("%s %d/%d", icons.diagnostics[severity], local_counts[severity], count)
				)
			)
		end
	end
	return table.concat(parts, " ")
end

Items.lsp_clients = function()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if #clients == 0 then
		return ""
	end

	local names = {}
	for _, server in pairs(clients) do
		table.insert(names, server.name)
	end
	local lsp_clients = "[" .. table.concat(names, " ") .. "]"

	return H.add_highlight2("ModeMsg", string.format("%s %s", "", lsp_clients))
end
Items.filetype = function()
	local filetype = vim.bo.filetype
	if filetype == "" then
		return ""
	end

	local icon, icon_hl = require("nvim-web-devicons").get_icon_by_filetype(filetype, { default = true })

	local hl = H.get_or_create_hl(icon_hl)
	return H.add_highlight(hl, icon) .. " " .. H.add_highlight(hl, filetype)
end
Items.encoding = function()
	local e = #vim.bo.fileencoding > 0 and vim.bo.fileencoding or vim.o.encoding

	local strs = {} ---@type string[]
	-- if e ~= "utf-8" then
	table.insert(strs, e)
	-- end

	local f = vim.bo.fileformat
	-- if f ~= "unix" then
	table.insert(strs, string.format("[%s]", f))
	-- end

	return H.add_highlight2("Normal", table.concat(strs))
end

Items.position = function()
	-- 65[12]/120
	return H.add_highlight2("Normal", "%2l(%02c)/%-3L")
	-- return "%2l(%02c)/%-3L"
end

Items.ruler = function()
	-- 80%
	return H.add_highlight2("Normal", "%3p%%")
	-- return "%3p%%"
end

Items.harpoon = function()
	if vim.g.harpoon_enable_statusline then
		local buf = api.nvim_get_current_buf()

		local harpoon_list = { "" }

		local harpoon = require("harpoon")
		local list = harpoon:list()
		local length = list:length()
		local root_dir = list.config:get_root_dir()
		for i = 1, length do
			local item = list:get(i).value
			if buf == vim.fn.bufnr(item) then
				table.insert(harpoon_list, string.format("[%d]", i))
			else
				table.insert(harpoon_list, string.format("%d", i))
			end
		end
		return H.add_highlight2("Normal", table.concat(harpoon_list, " "))
	end
	return ""
end

function Items.special_file_type()
	return H.add_highlight2("ModeMsg", string.upper(vim.bo.filetype))
end

--- Renders the statusline.
---@return string
_G.nvim_statsline = function()
	---@param items string[]
	---@return string
	local function contact_items(items)
		return vim.iter(items):skip(1):fold(items[1], function(acc, item)
			return string.format("%s%s", acc, item)
		end)
	end

	if vim.bo.filetype == "qf" then
		return contact_items({
			Items.special_file_type(),
			H.add_highlight2("Normal", " %q"),
			H.align(),
			Items.position(),
			H.space(),
			Items.ruler(),
		})
	end

	if vim.bo.filetype == "help" then
		return contact_items({
			Items.special_file_type(),
			H.space(),
			H.truncate(Items.buf_name()),
			H.align(),
			Items.position(),
			H.space(),
			Items.ruler(),
		})
	end

	if
		vim.tbl_contains({
			"nofile",
			-- "nowrite",
			"terminal",
			"prompt",
		}, vim.bo.buftype)
		or vim.tbl_contains({
			"fugitive",
			"fugitiveblame",
			"minifiles",
		}, vim.bo.filetype)
	then
		return contact_items({
			Items.special_file_type(),
			H.align(),
			Items.position(),
			H.space(),
			Items.ruler(),
		})
	end

	return contact_items({
		Items.mode(),
		H.sep(),
		Items.preview_window(),
		Items.diff_window(),
		Items.work_dir(),
		H.space(),
		H.truncate(Items.buf_name()),
		Items.buf_flag(),
		H.space(),
		Items.git(),
		H.align(),
		Items.harpoon(),
		H.space(),
		Items.dap(),
		H.space(),
		Items.diagnostics(),
		H.space(),
		Items.lsp_clients(),
		H.space(),
		Items.filetype(),
		H.space(),
		Items.encoding(),
		H.space(),
		Items.position(),
		H.space(),
		Items.ruler(),
	})
end

api.nvim_create_autocmd({
	"DiagnosticChanged",
	"ModeChanged",
}, {
	command = "redrawstatus",
})

vim.o.statusline = "%!v:lua.nvim_statsline()"
