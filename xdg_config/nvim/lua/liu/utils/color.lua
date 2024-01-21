local api = vim.api

local M = {}

---Get normalised color
---@param name string like 'pink' or '#fa8072'
---@return string[] rgb
local get_color = function(name)
	local color = api.nvim_get_color_by_name(name)
	if color == -1 then
		color = vim.opt.background:get() == "dark" and 000 or 255255255
	end

	---Convert color to hex
	---@param value integer
	---@param offset integer
	---@return integer
	local byte = function(value, offset)
		return bit.band(bit.rshift(value, offset), 0xFF)
	end

	return { byte(color, 16), byte(color, 8), byte(color, 0) }
end

---Get visually transparent color
---@param fg string like 'pink' or '#fa8072'
---@param bg string like 'pink' or '#fa8072'
---@param alpha integer number between 0 and 1
---@return string color #rrggbb string
M.blend = function(fg, bg, alpha)
	local bg_color = get_color(bg)
	local fg_color = get_color(fg)

	---@param i integer
	---@return integer
	local channel = function(i)
		local ret = (alpha * fg_color[i] + ((1 - alpha) * bg_color[i]))
		return math.floor(math.min(math.max(0, ret), 255) + 0.5)
	end

	return string.format("#%02X%02X%02X", channel(1), channel(2), channel(3))
end

---Get fg and bg of a highlight, fallback to `Normal`
---@param highlight string
---@return {bg:string,fg:string}
M.get_hl_color = function(highlight)
	local hl = api.nvim_get_hl(0, { name = highlight })
	local normal_hl = api.nvim_get_hl(0, { name = "Normal" }) -- fallback to `Normal`
	local bg = hl.bg or normal_hl.bg
	local fg = hl.fg or normal_hl.fg
	return {
		bg = ("#%06x"):format(bg),
		fg = ("#%06x"):format(fg),
	}
end

return M
