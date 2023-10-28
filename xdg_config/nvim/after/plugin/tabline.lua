if false then
	return
end

local M = {}

---@class color
---@field fg string
---@field bg string

---extract highlight
---@param hl string
---@return color|nil
local extract_highlight_colors = function(hl)
	if vim.fn.hlexists(hl) == 0 then
		return nil
	end

	local color = vim.api.nvim_get_hl(0, { name = hl })
	if color.background ~= nil then
		color.bg = string.format("#%06x", color.background)
		color.background = nil
	end
	if color.foreground ~= nil then
		color.fg = string.format("#%06x", color.foreground)
		color.foreground = nil
	end
	return color
end

---create a highlight for specificed filetype and return the highlight name
---@param color color
---@param ft string
---@return string
local create_highlight_group = function(color, ft)
	if color.bg and color.fg then
		local highlight_group_name = table.concat({ "user", "tab", "hl", ft }, "_")
		vim.api.nvim_set_hl(0, highlight_group_name, { fg = color.fg, bg = color.bg })
		return highlight_group_name
	end
	return "Normal"
end

---Get the icon
---@param bufnr number
---@param isSelected boolean
---@return string
M.icon = function(bufnr, isSelected)
	local filetype = vim.fn.getbufvar(bufnr, "&filetype")
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
	local buftype = vim.fn.getbufvar(bufnr, "&buftype")
	local filetype = vim.fn.getbufvar(bufnr, "&filetype")

	-- special buftypes
	local buftypes = {
		"prompt",
		"quickfix",
	}
	for _, bt in ipairs(buftypes) do
		if buftype:find(bt) then
			return (buftype:gsub("^%l", string.upper))
		end
	end

	-- file name
	local bufname = vim.fn.bufname(bufnr)
	if bufname == "" then
		return "[No Name]"
	end
	local file_name = vim.fn.fnamemodify(bufname, ":t")

	if buftype == "help" then
		return "Help: " .. file_name
	end

	-- special filetypes
	local filetypes = {
		"^git.*",
		"oil",
		"harpoon",
		"fugitive",
		"checkhealth",
	}
	for _, ftp in ipairs(filetypes) do
		if filetype:find(ftp) then
			return (filetype:gsub("^%l", string.upper))
		end
	end

	return file_name or ""
end

---Get modified sign
---@param bufnr number
---@return string
M.modified = function(bufnr)
	return vim.fn.getbufvar(bufnr, "&modified") == 1 and "[+] " or ""
end

local separator = function(index)
	return (index < vim.fn.tabpagenr("$") and "%#TabLine#|" or "")
end

---single table item
---@param index number
---@return string
M.tab = function(index)
	local winnr = vim.fn.tabpagewinnr(index)
	local bufnr = vim.fn.tabpagebuflist(index)[winnr]

	local isSelected = vim.fn.tabpagenr() == index
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
	local last_index = vim.fn.tabpagenr("$")
	local tabs = ""
	for index = 1, last_index do
		tabs = tabs .. M.tab(index)
	end
	tabs = tabs .. "%#TabLineFill#%="
	return tabs
end

_G.nvim_tabline = M.render

vim.opt.tabline = "%!v:lua.nvim_tabline()"
