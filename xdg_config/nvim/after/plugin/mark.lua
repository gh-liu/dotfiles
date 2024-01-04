if false then
	return
end

local sign_group_name = "liu/marks_signs"

local mark_sign_ns = vim.api.nvim_create_namespace(sign_group_name)

local sign_priority = 10

---@param mark string
---@return boolean
local function is_lowercase_mark(mark)
	return 97 <= mark:byte() and mark:byte() <= 122
end

---@param mark string
---@return boolean
local function is_uppercase_mark(mark)
	return 65 <= mark:byte() and mark:byte() <= 90
end

---@param mark string
---@return boolean
local function is_letter_mark(mark)
	return is_lowercase_mark(mark) or is_uppercase_mark(mark)
end

--- Map of mark information per buffer.
---@type table<integer, table<string, {line: integer, id: integer}>>
local cache_marks = {}

---@param mark string
---@param bufnr integer
local function delete_mark(mark, bufnr)
	local buffer_marks = cache_marks[bufnr]
	if not buffer_marks or not buffer_marks[mark] then
		return
	end

	vim.api.nvim_buf_del_extmark(bufnr, mark_sign_ns, buffer_marks[mark].id)
	buffer_marks[mark] = nil

	vim.cmd("delmarks " .. mark)
end

---@param mark string
---@param bufnr integer
---@param line integer
local function register_mark(mark, bufnr, line)
	local buffer_marks = cache_marks[bufnr]
	if not buffer_marks then
		return
	end

	-- Mark already exists, remove it first.
	if buffer_marks[mark] then
		delete_mark(mark, bufnr)
	end

	line = line - 1
	local id = vim.api.nvim_buf_set_extmark(0, mark_sign_ns, line, 0, {
		sign_text = mark,
		sign_hl_group = "MoreMsg",
		priority = sign_priority,
	})
	buffer_marks[mark] = { line = line, id = id }
end

local map_add_mark = function(bufnr, mark)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	register_mark(mark, bufnr, vim.api.nvim_win_get_cursor(0)[1])
	vim.cmd("normal! m" .. mark)
end

local map_delete_mark = function(bufnr, mark)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	delete_mark(mark, bufnr)
end

-- A-Z
for i = 65, 90, 1 do
	local c = string.char(i)
	vim.keymap.set("n", "m" .. c, function()
		map_add_mark(nil, c)
	end, {})

	vim.keymap.set("n", "dm" .. c, function()
		map_delete_mark(nil, c)
	end, {})
end
---@param bufnr integer
local function on_attach(bufnr)
	-- a-z
	for i = 97, 122, 1 do
		local c = string.char(i)
		vim.keymap.set("n", "m" .. c, function()
			map_add_mark(bufnr, c)
		end, {
			buffer = bufnr,
		})

		vim.keymap.set("n", "dm" .. c, function()
			map_delete_mark(bufnr, c)
		end, {
			buffer = bufnr,
		})
	end

	vim.keymap.set("n", "M", "g`", {
		desc = "Jump to the exact location of a mark",
		buffer = bufnr,
	})
end

local sign_augroup = vim.api.nvim_create_augroup(sign_group_name, { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
	group = sign_augroup,
	callback = function(args)
		local bufnr = args.buf
		if cache_marks[bufnr] then
			-- Remove all marks that were deleted.
			for mark, _ in pairs(cache_marks[bufnr]) do
				if vim.api.nvim_buf_get_mark(bufnr, mark)[1] == 0 then
					delete_mark(mark, bufnr)
					vim.print("delete mark '" .. mark)
				end
			end
		end
	end,
})

-- Set up autocommands to refresh the signs.
vim.api.nvim_create_autocmd("BufWinEnter", {
	group = sign_augroup,
	callback = function(args)
		local bufnr = args.buf

		-- Only handle normal buffers.
		local bt = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
		if bt ~= "" then
			return true
		end

		-- Init mark information for per buffer.
		if not cache_marks[bufnr] then
			cache_marks[bufnr] = {}
		end

		local local_marks = vim.fn.getmarklist(bufnr)
		local global_marks = vim.fn.getmarklist()

		local register_marks = function(marks)
			for _, data in ipairs(marks) do
				local mark = data.mark:sub(2, 3) -- name of the mark prefixed by "'"
				local mark_buf, mark_line = unpack(data.pos) -- [bufnum, lnum, col, off]

				local cached_mark = cache_marks[bufnr][mark]
				if
					mark_buf == bufnr
					and is_letter_mark(mark)
					and (not cached_mark or cached_mark.line ~= mark_line)
				then
					register_mark(mark, bufnr, mark_line)
				end
			end
		end
		-- The global marks
		register_marks(vim.fn.getmarklist())
		-- The local marks
		register_marks(vim.fn.getmarklist(bufnr))

		-- Set custom mappings.
		on_attach(bufnr)
	end,
})
