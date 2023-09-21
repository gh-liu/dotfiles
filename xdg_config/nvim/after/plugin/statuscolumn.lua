if true then
	return
end

_G.__signcolumn = function()
	if vim.v.virtnum < 0 then
		return ""
	end

	return "%s"
end

_G.__number = function()
	if vim.v.virtnum < 0 then
		return ""
	end

	local nu = vim.opt.number:get()
	local rnu = vim.opt.relativenumber:get()
	local is_cur_line = vim.fn.line(".") == vim.v.lnum
	local line = is_cur_line and vim.v.lnum or vim.v.relnum

	local width = #tostring(vim.api.nvim_buf_line_count(0))
	local nuw = vim.opt.numberwidth:get()
	width = nuw <= width and nuw or width

	local function pad_start(n, is_cur_line)
		local len = width - #tostring(n)
		return (len < 1 and n) or (is_cur_line and n .. (" "):rep(len)) or (" "):rep(len) .. n
	end

	if nu and rnu then
		return pad_start(line, is_cur_line)
	elseif nu then
		return pad_start(vim.v.lnum, is_cur_line)
	elseif rnu then
		return pad_start(vim.v.relnum, is_cur_line)
	end

	return ""
end

vim.o.foldcolumn = "1"
_G.__foldcolumn = function()
	if vim.v.virtnum < 0 then
		return ""
	end

	local fc = "%#FoldColumn#"
	local clf = "%#CursorLineFold#"
	local hl = vim.fn.line(".") == vim.v.lnum and clf or fc

	local chars = vim.opt.fillchars:get()
	if vim.fn.foldlevel(vim.v.lnum) > vim.fn.foldlevel(vim.v.lnum - 1) then
		if vim.fn.foldclosed(vim.v.lnum) == -1 then
			return hl .. (chars.foldopen or " ")
		else
			return hl .. (chars.foldclose or " ")
		end
	elseif vim.fn.foldlevel(vim.v.lnum) == 0 then
		return hl .. " "
	else
		return hl .. (chars.foldsep or " ")
	end
end

local space = " "
vim.wo.statuscolumn = vim.fn.join({
	"%{%v:lua.__signcolumn()%}%=",
	"%{v:lua.__number()}",
	space,
	"%{%v:lua.__foldcolumn()%}",
	"%#Comment#│",
	space,
}, "")
