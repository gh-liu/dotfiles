if false then
	return
end

local fn = vim.fn
local api = vim.api

local sign_priority = 10
local sign_hl = "MoreMsg"

local sign_group_name = "liu/marks_signs"

local mark_sign_ns = api.nvim_create_namespace(sign_group_name)

---@param mark string
---@return boolean
local function uppercase_letter_mark(mark)
	-- :h lua-patterns
	return mark:match("%u")
end

---@param mark string
---@return boolean
local function lowercase_letter_mark(mark)
	-- :h lua-patterns
	return mark:match("%l")
end

local M = {}

--- Map of mark information per buffer.
---@type table<integer, table<string, {line: integer, id: integer}>>
M.cache_marks = {}

---@param mark string
---@param bufnr integer|nil
M.delete_mark_sign = function(mark, bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()

	local cache_marks = M.cache_marks[bufnr]
	-- Mark not exists, just return.
	if not cache_marks or not cache_marks[mark] then
		return
	end

	api.nvim_buf_del_extmark(bufnr, mark_sign_ns, cache_marks[mark].id)
	cache_marks[mark] = nil
end

---@param mark string
---@param bufnr integer|nil
M.delete_mark = function(mark, bufnr)
	if bufnr then
		M.delete_mark_sign(mark, bufnr)
	else
		for buf, marks in pairs(M.cache_marks) do
			if marks[mark] then
				M.delete_mark_sign(mark, buf)
			end
		end
	end
	vim.cmd("delmarks " .. mark)
end

---@param mark string
---@param bufnr integer|nil
---@param line integer|nil
M.add_mark_sign = function(mark, bufnr, line)
	bufnr = bufnr or api.nvim_get_current_buf()
	-- Marks of buffer not exists, create cache first.
	if not M.cache_marks[bufnr] then
		M.cache_marks[bufnr] = {}
	end
	-- Mark already exists, remove it first.
	if uppercase_letter_mark(mark) then
		M.delete_mark(mark)
	end
	if lowercase_letter_mark(mark) and M.cache_marks[bufnr][mark] then
		M.delete_mark(mark, bufnr)
	end

	line = line or api.nvim_win_get_cursor(0)[1]
	line = line - 1
	local opts = { sign_text = mark, sign_hl_group = sign_hl, priority = sign_priority }
	local id = api.nvim_buf_set_extmark(bufnr, mark_sign_ns, line, 0, opts)
	M.cache_marks[bufnr][mark] = { line = line, id = id }
end

---@param mark string
---@param bufnr integer|nil
---@param line integer|nil
M.add_mark = function(mark, bufnr, line)
	M.add_mark_sign(mark, bufnr, line)
	vim.cmd("normal! m" .. mark)
end

---@param bufnr integer
local function add_buf_maps(bufnr)
	local keymap = vim.keymap
	-- buffer: a-z
	for i = 97, 122, 1 do
		local c = string.char(i)
		keymap.set("n", "m" .. c, function()
			M.add_mark(c, bufnr)
		end, { buffer = bufnr })

		keymap.set("n", "dm" .. c, function()
			M.delete_mark(c, bufnr)
		end, { buffer = bufnr })
	end
end

local function add_global_maps()
	local keymap = vim.keymap
	-- global: A-Z
	for i = 65, 90, 1 do
		local c = string.char(i)
		keymap.set("n", "m" .. c, function()
			M.add_mark(c)
		end, { desc = "mark '" .. c })

		keymap.set("n", "dm" .. c, function()
			M.delete_mark(c)
		end, { desc = "delete mark '" .. c })
	end

	keymap.set("n", "M", "g`", { desc = "Jump to the exact location of a mark" })
end

local register_marks = function(marks, bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	for _, data in ipairs(marks) do
		local mark = data.mark:sub(2, 3) -- name of the mark prefixed by "'"
		local mark_buf, mark_line = unpack(data.pos) -- [bufnum, lnum, col, off]

		if mark_buf == bufnr and (uppercase_letter_mark(mark) or lowercase_letter_mark(mark)) then
			M.add_mark_sign(mark, bufnr, mark_line)
		end
	end
end

local group = api.nvim_create_augroup(sign_group_name, { clear = true })

-- This difference between `BufEnter` and `BufWinEnter`
-- 1. BufEnter X:
-- It was bufnr() != X
-- But now it becomes bufnr() == X
-- 2. BufWinEnter X:
-- It was len(win_findbuf(X)) == 0
-- But now it becomes len(win_findbuf(X)) == 1

M.setup = function()
	add_global_maps()

	api.nvim_create_autocmd({ "BufEnter" }, {
		group = group,
		callback = function(args)
			local bufnr = args.buf
			-- local bt = api.nvim_get_option_value("buftype", { buf = bufnr })
			-- if bt ~= "" then
			-- 	return true
			-- end

			if not vim.b.mark_sign_init then
				vim.b.mark_sign_init = true
				add_buf_maps(bufnr)

				-- The global marks
				register_marks(fn.getmarklist(), bufnr)
				-- The local marks
				register_marks(fn.getmarklist(bufnr), bufnr)
			end
		end,
	})
end

M.setup()
