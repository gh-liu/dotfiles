if false then
	return
end

local api = vim.api
local fn = vim.fn

local M = {}

---@class color
---@field fg string
---@field bg string

---extract highlight
---@param highlight string
---@return color|nil
local extract_highlight_colors = function(highlight)
	if fn.hlexists(highlight) == 0 then
		return nil
	end
	local hl = api.nvim_get_hl(0, { name = highlight })
	local bg = hl.bg and ("#%06x"):format(hl.bg) or nil
	local fg = hl.fg and ("#%06x"):format(hl.fg) or nil
	return {
		bg = bg,
		fg = fg,
	}
end

---create a highlight for specificed filetype and return the highlight name
---@param color color
---@param ft string
---@return string
local create_highlight_group = function(color, ft)
	if color.bg and color.fg then
		local highlight_group_name = table.concat({ "user", "tab", "hl", ft }, "_")
		api.nvim_set_hl(0, highlight_group_name, { fg = color.fg, bg = color.bg })
		return highlight_group_name
	end
	return "Normal"
end

---Get the icon
---@param bufnr number
---@param isSelected boolean
---@return string
M.icon = function(bufnr, isSelected)
	local filetype = api.nvim_get_option_value("filetype", { buf = bufnr })

	if filetype == "" then
		return ""
	end

	local icon, icon_color = require("nvim-web-devicons").get_icon_color_by_filetype(filetype, { default = true })

	local tabline_colors = extract_highlight_colors("TabLineSel")

	local hl = create_highlight_group({ bg = tabline_colors.bg, fg = icon_color }, filetype)
	local selectedHlStart = (isSelected and hl) and "%#" .. hl .. "#" or ""
	local selectedHlEnd = isSelected and "%#TabLineSel#" or ""

	return selectedHlStart .. icon .. selectedHlEnd .. " "
end

---Get the title
---@param bufnr number
---@return string
M.title = function(bufnr)
	local buftype = api.nvim_get_option_value("buftype", { buf = bufnr })
	-- special buftype
	local buftypes = {
		"quickfix",
		"terminal",
		"prompt",
		"help",
	}
	for _, bt in ipairs(buftypes) do
		if buftype:find(bt) then
			return (buftype:gsub("^%l", string.upper))
		end
	end

	local filetype = api.nvim_get_option_value("filetype", { buf = bufnr })
	-- special filetype
	local filetypes = {
		"^git.*",
		"fugitive",
		"checkhealth",
	}
	for _, ftp in ipairs(filetypes) do
		if filetype:find(ftp) then
			return (filetype:gsub("^%l", string.upper))
		end
	end
	if vim.b[bufnr].ft_as_tabline_title then
		return (filetype:gsub("^%l", string.upper))
	end

	-- file name
	local bufname = api.nvim_buf_get_name(bufnr)
	if bufname == "" then
		return "[No Name]"
	end
	local fname = fn.fnamemodify(bufname, ":t")

	return fname or ""
end

---Get modified sign
---@param bufnr number
---@return string
M.modified = function(bufnr)
	return fn.getbufvar(bufnr, "&modified") == 1 and "[+] " or ""
end

local separator = function(index)
	return (index < fn.tabpagenr("$") and "%#TabLine#|" or "")
end

---single table item
---@param index number
---@return string
M.tab = function(index)
	local winnr = fn.tabpagewinnr(index)
	local bufnr = fn.tabpagebuflist(index)[winnr]

	local isSelected = fn.tabpagenr() == index
	local hl = (isSelected and "%#TabLineSel#" or "%#TabLine#")

	return hl
		.. "%"
		.. index
		.. "T"
		.. " "
		.. M.icon(bufnr, isSelected)
		.. M.title(bufnr)
		.. " "
		.. M.modified(bufnr)
		.. "%T"
		.. separator(index)
end

M.render = function()
	local last_index = fn.tabpagenr("$")
	local tabs = ""
	for index = 1, last_index do
		tabs = tabs .. M.tab(index)
	end
	tabs = tabs .. "%#TabLineFill#%="
	return tabs
end

_G.nvim_tabline = M.render

vim.opt.tabline = "%!v:lua.nvim_tabline()"
