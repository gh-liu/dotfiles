local extract_highlight_colors = function(color_group, scope)
	if vim.fn.hlexists(color_group) == 0 then
		return nil
	end

	local color = vim.api.nvim_get_hl_by_name(color_group, true)
	if color.background ~= nil then
		color.bg = string.format("#%06x", color.background)
		color.background = nil
	end
	if color.foreground ~= nil then
		color.fg = string.format("#%06x", color.foreground)
		color.foreground = nil
	end

	if scope then
		return color[scope]
	end
	return color
end

local create_highlight_group = function(color, ft)
	if color.bg and color.fg then
		local highlight_group_name = table.concat({ "user", "tab", ft }, "_")
		vim.api.nvim_set_hl(0, highlight_group_name, { fg = color.fg, bg = color.bg })
		return highlight_group_name
	end
end
local icon = function(bufnr, isSelected)
	local filetype = vim.fn.getbufvar(bufnr, "&filetype")
	if filetype == "" then
		return ""
	end

	local icon, color = require("nvim-web-devicons").get_icon_color_by_filetype(filetype, { default = true })

	local bg = extract_highlight_colors("TabLineSel", "bg")
	local hl = create_highlight_group({ bg = bg, fg = color }, filetype)
	local selectedHlStart = (isSelected and hl) and "%#" .. hl .. "#" or ""
	local selectedHlEnd = isSelected and "%#TabLineSel#" or ""

	return selectedHlStart .. icon .. selectedHlEnd .. " "
end

local title = function(bufnr)
	local bufname = vim.fn.bufname(bufnr)
	local file = vim.fn.fnamemodify(bufname, ":t")
	local buftype = vim.fn.getbufvar(bufnr, "&buftype")
	local filetype = vim.fn.getbufvar(bufnr, "&filetype")

	if buftype == "help" then
		return "Help: " .. file
	end

	local buftypes = {
		"prompt",
		"quickfix",
	}
	for _, btp in ipairs(buftypes) do
		if buftype:find(btp) then
			return (buftype:gsub("^%l", string.upper))
		end
	end

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

	if bufname == "" then
		return "[No Name]"
	end

	-- vim.print(file)

	return file
end

local modified = function(bufnr)
	return vim.fn.getbufvar(bufnr, "&modified") == 1 and "[+] " or ""
end

local separator = function(index)
	return (index < vim.fn.tabpagenr("$") and "%#TabLine#|" or "")
end

local tab = function(index)
	local winnr = vim.fn.tabpagewinnr(index)
	local bufnr = vim.fn.tabpagebuflist(index)[winnr]

	local isSelected = vim.fn.tabpagenr() == index
	local hl = (isSelected and "%#TabLineSel#" or "%#TabLine#")

	return hl
		.. "%"
		.. index
		.. "T"
		.. " "
		.. icon(bufnr, isSelected)
		.. title(bufnr)
		.. " "
		.. modified(bufnr)
		.. "%T"
		.. separator(index)
end

local tabline = function()
	local last_index = vim.fn.tabpagenr("$")

	local line = ""
	for index = 1, last_index do
		line = line .. tab(index)
	end
	line = line .. "%#TabLineFill#%="

	return line
end

function _G.nvim_tabline()
	return tabline()
end

vim.opt.tabline = "%!v:lua.nvim_tabline()"
