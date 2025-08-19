local fn = vim.fn

---@class qftf_info
---@field id integer
---@field start_idx integer
---@field end_idx integer
---@field winid integer
---@field quickfix 1|0

---@class qfitem
---@field text string
---@field type string
---@field lnum integer line number in the buffer (first line is 1)
---@field end_lnum integer end of line number if the item is multiline
---@field col integer column number (first column is 1)
---@field end_col integer end of column number if the item has range
---@field vcol 0|1 if true "col" is visual column. If false "col" is byte index
---@field nr integer error number
---@field pattern string search pattern used to locate the error
---@field bufnr integer number of buffer that has the file name
---@field module string
---@field valid 0|1
---@field user_data? any

-- :h qftf
-- :h quickfix-window-function
---
---@param info qftf_info
---@return string[]
function _G.QuickfixTextFunc(info)
	local results = {}

	local items
	if info.quickfix == 1 then
		items = fn.getqflist({ id = info.id, items = 0 }).items
	else
		items = fn.getloclist(info.winid, { id = info.id, items = 0 }).items
	end

	local align_str = function(fname, limit)
		limit = limit or 31
		if limit > 31 then
			limit = 66
		end
		local fmt1 = "%-" .. limit .. "s"
		local fmt2 = "…%." .. (limit - 1) .. "s"
		if #fname <= limit then
			fname = fmt1:format(fname)
		else
			fname = fmt2:format(fname:sub(1 - limit))
		end
		return fname
	end

	local modules = {}
	local module_max_len = 0
	local fnames = {}
	local fname_max_len = 0
	local lnum_max_len = 1
	local col_max_len = 1
	for i = info.start_idx, info.end_idx do
		local item = items[i] ---@type qfitem

		local lnum_str_len = #tostring(item.lnum)
		if lnum_str_len > lnum_max_len then
			lnum_max_len = lnum_str_len
		end
		local col_str_len = #tostring(item.col)
		if col_str_len > col_max_len then
			col_max_len = col_str_len
		end

		-- local moduls = ""
		local fname = ""
		if item.valid == 1 then
			if #item.module > 0 then
				if #item.module > module_max_len then
					module_max_len = #item.module
				end
				modules[i] = item.module
			end

			fnames[i] = fname
			if item.bufnr > 0 then
				fname = fn.bufname(item.bufnr)
				if fname == "" then
					fname = "[No Name]"
				else
					fname = fname:gsub("^" .. vim.env.HOME, "~")
				end
				if #fname > fname_max_len then
					fname_max_len = #fname
				end
				fnames[i] = fname
			end
		end
	end

	local show_fname = #fnames > 0
	local show_module = #modules > 0

	local cols = vim.o.columns
	local limit

	local entry_fmt = "%s |%" .. lnum_max_len .. "d:%-" .. col_max_len .. "d|%s %s"
	for idx = info.start_idx, info.end_idx do
		local item = items[idx] ---@type qfitem

		local str

		if show_module or show_fname then
			local lnum = item.lnum > 99999 and -1 or item.lnum
			local col = item.col > 999 and -1 or item.col
			local qtype = item.type == "" and "" or " " .. item.type:sub(1, 1):upper()

			local prefix_max_len
			local prefix_raw
			if show_module then
				prefix_max_len = module_max_len
				prefix_raw = modules[idx]

				-- NOTE: for fugitive object
				local hash, file = string.match(prefix_raw or "", "^(%x+):(.*)$")
				if hash and file then
					prefix_raw = string.sub(hash, 1, 7) .. ":" .. file
				end
			else
				prefix_max_len = fname_max_len
				prefix_raw = fnames[idx]
			end

			limit = limit or math.min(math.max(20, math.floor(cols * 0.3)), prefix_max_len)
			local prefix = align_str(prefix_raw or "", prefix_max_len)

			str = entry_fmt:format(prefix, lnum, col, qtype, vim.trim(item.text))
		else
			str = item.text
		end

		table.insert(results, str)
	end
	return results
end

vim.o.quickfixtextfunc = "v:lua._G.QuickfixTextFunc"
