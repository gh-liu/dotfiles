local api = vim.api
local fn = vim.fn
local bo = vim.bo

local M = {}

-- file modified color
vim.cmd([[hi StatuslineFilenameModified guifg=#d75f5f gui=bold guibg=#3a3a3a]])
vim.cmd([[hi StatuslineFilenameNoMod guifg=#e9e9e9 gui=bold guibg=#3a3a3a]])

-- file name color
local function filename_color()
	local filename_color = "StatuslineFilenameNoMod"
	if vim.bo.modified then
		filename_color = "StatuslineFilenameModified"
	end
	return filename_color
end

-- file name
function M.file_name()
	local win_id = api.nvim_get_current_win()
	-- local buf_nr = api.nvim_win_get_buf(win_id)
	-- local buf_name = api.nvim_buf_get_name(buf_nr)
	local buf_name = api.nvim_buf_get_name(0)

	local file_name = fn.fnamemodify(buf_name, [[:~:.]])

	local space = math.min(60, math.floor(0.5 * api.nvim_win_get_width(win_id)))
	if string.len(file_name) > space then
		file_name = fn.pathshorten(file_name)
	end

	return file_name
end

-- is file modified
function M.modified_symbol()
	if bo.modified then
		vim.cmd([[hi StatuslineModified guibg=#3a3a3a gui=bold guifg=#d75f5f]])
		return "●"
	else
		vim.cmd([[ hi StatuslineModified guibg=#3a3a3a gui=bold guifg=#afaf00]])
		return ""
	end
end

-- is file readonly
function M.is_file_readonly()
	return ((vim.o.paste and vim.bo.readonly) and " " or "") and "%r" .. (vim.bo.readonly and " " or "")
end

function M.file_size()
	local suffix = { "b", "k", "M", "G", "T", "P", "E" }
	local index = 1

	local fsize = fn.getfsize(api.nvim_buf_get_name(0))
	if fsize < 0 then
		fsize = 0
	end
	while fsize > 1024 and index < 7 do
		fsize = fsize / 1024
		index = index + 1
	end

	return string.format(index == 1 and "%g%s" or "%.2f%s", fsize, suffix[index])
end

function M.file_encoding()
	return ((bo.fenc ~= "" and bo.fenc) or vim.o.enc):upper()
end

function M.file_format()
	return ((bo.fileformat ~= "" and bo.fileformat) or vim.o.fileformat):upper()
end

function M.file_type()
	local filetype = bo.filetype

	local filename = api.nvim_buf_get_name(0)
	local extension = fn.fnamemodify(filename, ":e")

	local icon

	local icon_str, icon_color = require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })

	icon = { str = icon_str }
	icon.hl = { fg = icon_color }

	filetype = " " .. filetype
	filetype = filetype:gsub("%a", string.upper, 1)
	-- filetype = filetype:upper()

	return filetype, icon
end

function M.get_info()
	-- fileinfo(buf_nr,bufname,set_modified_symbol)
	local format_str = "%%#StatuslineModified# %s %%#%s#<%s> %s "

	local filename_color = filename_color()
	local buf_nr = vim.api.nvim_win_get_buf(win_id)
	local buf_name = M.file_name()

	local buf_modified = M.modified_symbol()

	return string.format(format_str, buf_modified, filename_color, buf_nr, buf_name)
end

return M
