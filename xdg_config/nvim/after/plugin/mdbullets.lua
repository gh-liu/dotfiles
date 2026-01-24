-- Markdown auto-bullet extension
-- Provides intelligent list continuation for ordered and unordered lists.
--
-- Scenarios:
-- Insert-mode (newline-driven):
-- 1) Unordered list newline        => auto-insert "-/*/+" (indent-aware rotation)
-- 2) Task list newline             => auto-insert "- [ ]" (indent-aware bullet rotation)
-- 3) Ordered list newline          => auto-insert next number; renumber following siblings
-- 4) Second newline on empty item  => cancel the just-generated marker (exit list)
--
-- Insert-mode (post-newline adjustment):
-- 5) Tab/Shift-Tab on empty bullet => adjust unordered bullet to match indent level
-- 6) Edit ordered list number      => renumber forward when next sibling exists
--
-- Normal-mode:
-- 7) "o/O" on an empty line after a list item => generate a new list item on InsertEnter
-- 8) Ordered list row deletion (gap, e.g. "dd") => renumber from first surviving row; undo stays coherent (undojoin)
--
-- Safeguards:
-- - Only active for markdown buffers
-- - Only acts on blank new lines
-- - Ordered renumbering stops at empty lines, skips deeper indent, max 200 lines

local api = vim.api
local augroup = api.nvim_create_augroup("liu/mdbullets", { clear = true })

-- ====================================================================
-- Constants & State
-- ====================================================================

local BULLETS = { "-", "*", "+" }
local MAX_RENUMBER_LINES = 200
local DEBOUNCE_MS = 80

-- Lua-side debounce timers (cannot be stored in vim.b)
local debounce_timers = {}

-- ====================================================================
-- Utilities
-- ====================================================================

---@param buf integer
---@param row integer
---@return string
local function get_line(buf, row)
	return api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
end

---@param buf integer
---@param row integer
---@param text string
local function set_line_and_cursor(buf, row, text)
	api.nvim_buf_set_lines(buf, row, row + 1, false, { text })
	api.nvim_win_set_cursor(0, { row + 1, #text })
end

---@param line string
---@return boolean
local function is_empty(line)
	return line:match("^%s*$") ~= nil
end

---@param line string
---@return boolean
local function is_blocked(line)
	return line:match("^%s*```") ~= nil or line:match("^%s*>") ~= nil
end

---@param line string
---@return boolean
local function is_list_item(line)
	return line:match("^%s*[-*+]") ~= nil or line:match("^%s*%d+[%.%),]") ~= nil
end

---@param line string
---@return boolean
local function is_task_list(line)
	return line:match("^%s*[-*+]%s+%[[ xX]%]%s+") ~= nil
end

---@param line string
---@return boolean
local function is_empty_list_item(line)
	return line:match("^%s*[-*+]%s*$") ~= nil
		or line:match("^%s*[-*+]%s+%[[ xX]%]%s*$") ~= nil
		or line:match("^%s*%d+[%.%),]%s*$") ~= nil
end

---@param line string
---@return string indent, string|nil bullet
local function parse_unordered(line)
	return line:match("^(%s*)([-*+])%s+")
end

---@param line string
---@return string indent, string|nil num, string|nil delim
local function parse_ordered(line)
	return line:match("^(%s*)(%d+)([%.%),])%s+")
end

---@param a string
---@param b string
---@return boolean
local function either_blocked(a, b)
	return is_blocked(a) or is_blocked(b)
end

---@param buf integer
---@param row integer -- current row (0-based), already a newly-created blank line
---@param prev string -- previous line content
---@param state table
---@return boolean handled
local function cancel_empty_list_item_on_second_newline(buf, row, prev, state)
	if row <= 0 then
		return false
	end
	if not is_empty_list_item(prev) then
		return false
	end

	-- Typical UX: Enter on an empty list item exits the list without leaving a dangling marker.
	-- Our autocmd sees the state *after* the newline, so we:
	-- - remove the empty list marker line (row-1)
	-- - remove the extra newly-created blank line (row)
	-- and keep exactly one blank line with the same indent as the marker line.
	local indent = prev:match("^(%s*)") or ""
	api.nvim_buf_set_lines(buf, row - 1, row + 1, false, { indent })
	api.nvim_win_set_cursor(0, { row, #indent }) -- row (1-based) points to old (row-1)

	-- Reset list state so subsequent typing doesn't inherit previous list context.
	state._md_list_last_generated_row = nil
	state._md_list_indent_stack = nil
	state._md_list_last_row = row - 1
	return true
end

-- ====================================================================
-- Indent Stack (tracks bullets at different indent levels)
-- ====================================================================

local Stack = {}

function Stack.prune(stack, indent_len)
	while #stack > 0 and stack[#stack].indent > indent_len do
		table.remove(stack)
	end
end

function Stack.set_level(stack, indent_len, bullet)
	Stack.prune(stack, indent_len)
	if #stack == 0 or stack[#stack].indent < indent_len then
		table.insert(stack, { indent = indent_len, bullet = bullet })
	else
		stack[#stack].bullet = bullet
	end
end

function Stack.get_bullet(stack, indent_len)
	Stack.prune(stack, indent_len)
	if #stack > 0 and stack[#stack].indent == indent_len then
		return stack[#stack].bullet
	end
	return nil
end

local function next_bullet(b)
	for i, v in ipairs(BULLETS) do
		if v == b then
			return BULLETS[(i % #BULLETS) + 1]
		end
	end
	return "-"
end

---@param stack table
---@param prev_len number
---@param cur_len number
---@param prev_bullet string
---@return string bullet
local function compute_unordered_bullet(stack, prev_len, cur_len, prev_bullet)
	-- Always sync the previous level so new lists don't inherit stale bullets.
	Stack.set_level(stack, prev_len, prev_bullet)

	local use
	if cur_len > prev_len then
		use = next_bullet(prev_bullet)
	else
		use = Stack.get_bullet(stack, cur_len) or prev_bullet
	end

	Stack.set_level(stack, cur_len, use)
	return use
end

-- ====================================================================
-- Unordered List Handlers
-- ====================================================================

---@param buf integer
---@param row integer
---@param line string
---@param prev string
---@param state table
---@return boolean handled
local function handle_unordered_newline(buf, row, line, prev, state)
	local prev_indent, prev_bullet = parse_unordered(prev)
	if not prev_bullet then
		return false
	end

	local cur_indent = line:match("^(%s*)") or ""
	local stack = state._md_list_indent_stack or {}
	local bullet = compute_unordered_bullet(stack, #prev_indent, #cur_indent, prev_bullet)

	state._md_list_indent_stack = stack
	set_line_and_cursor(buf, row, cur_indent .. bullet .. " ")
	state._md_list_last_generated_row = row
	return true
end

---@param buf integer
---@param row integer
---@param line string
---@param prev string
---@param state table
---@return boolean handled
local function adjust_unordered_indent(buf, row, line, prev, state)
	local cur_indent, cur_bullet = line:match("^(%s*)([-*+])%s*")
	if not cur_bullet then
		return false
	end

	local prev_indent, prev_bullet = parse_unordered(prev)
	if not prev_bullet then
		return false
	end

	local stack = state._md_list_indent_stack or {}
	local bullet = compute_unordered_bullet(stack, #prev_indent, #cur_indent, prev_bullet)
	state._md_list_indent_stack = stack

	-- Only change if bullet is different (preserve any text after bullet)
	if bullet ~= cur_bullet then
		local rest = line:sub(#cur_indent + 2)  -- skip indent and bullet
		local text = cur_indent .. bullet .. rest
		set_line_and_cursor(buf, row, text)
	end
	return true
end

---@param buf integer
---@param row integer
---@param line string
---@param prev string
---@param state table
---@return boolean handled
local function handle_task_list_newline(buf, row, line, prev, state)
	local indent, bullet = prev:match("^(%s*)([-*+])%s+%[[ xX]%]%s+")
	if not bullet then
		return false
	end

	local cur_indent = line:match("^(%s*)") or ""
	local stack = state._md_list_indent_stack or {}
	local use = compute_unordered_bullet(stack, #indent, #cur_indent, bullet)
	state._md_list_indent_stack = stack

	set_line_and_cursor(buf, row, cur_indent .. use .. " [ ] ")
	state._md_list_last_generated_row = row
	return true
end

-- ====================================================================
-- Ordered List Handlers
-- ====================================================================

---@param buf integer
---@param start_row integer
---@param indent string
---@param delim string
---@param start_num integer
local function renumber_ordered(buf, start_row, indent, delim, start_num)
	local row, num = start_row, start_num
	local scanned = 0

	while scanned < MAX_RENUMBER_LINES do
		local line = get_line(buf, row)
		if not line or is_empty(line) then
			break
		end

		-- Skip deeper indent blocks (nested lists/code)
		local line_indent = line:match("^(%s*)")
		if #line_indent > #indent then
			row = row + 1
			scanned = scanned + 1
			goto continue
		end

		local ind, _, line_delim = parse_ordered(line)
		if not ind or ind ~= indent or line_delim ~= delim then
			break
		end

		local rest = line:gsub("^%s*%d+[%.%),]%s+", "")
		local new_line = indent .. num .. delim .. " " .. rest
		if new_line ~= line then
			api.nvim_buf_set_lines(buf, row, row + 1, false, { new_line })
		end

		num = num + 1
		row = row + 1
		scanned = scanned + 1
		::continue::
	end
end

---@param buf integer
---@param row integer
---@param prev string
---@param state table
---@return boolean handled
local function handle_ordered_newline(buf, row, prev, state)
	local indent, num, delim = parse_ordered(prev)
	if not num then
		return false
	end

	local next_num = tonumber(num) + 1
	set_line_and_cursor(buf, row, indent .. next_num .. delim .. " ")
	renumber_ordered(buf, row + 1, indent, delim, next_num + 1)
	state._md_list_last_generated_row = row
	return true
end

---@param buf integer
---@param row integer
---@param line string
---@param prev string|nil
---@return boolean handled
local function adjust_ordered_on_edit(buf, row, line, prev)
	local cur_indent, cur_num, cur_delim = parse_ordered(line)
	if not cur_num then
		return false
	end

	local actual_num = tonumber(cur_num)
	local expected_num

	-- Determine expected number
	if row == 0 or not prev or prev == "" then
		expected_num = 1  -- First line should be 1
	else
		local prev_indent, prev_num, prev_delim = parse_ordered(prev)
		if not prev_num or prev_indent ~= cur_indent or prev_delim ~= cur_delim then
			return false  -- Different list context
		end
		expected_num = tonumber(prev_num) + 1
	end

	-- Renumber if current number is wrong
	if actual_num ~= expected_num then
		renumber_ordered(buf, row, cur_indent, cur_delim, expected_num)
		return true
	end

	return false
end

-- ====================================================================
-- Core Logic
-- ====================================================================

---@param buf integer
local function md_bullets(buf)
	local state = vim.b[buf]
	if state._md_list_guard then
		return
	end
	state._md_list_guard = true

	-- Verify we're still in the same buffer
	if api.nvim_get_current_buf() ~= buf then
		state._md_list_guard = false
		return
	end

	local row = api.nvim_win_get_cursor(0)[1] - 1
	local line = get_line(buf, row)

	-- Detect newline: row increased since last call
	local last_row = state._md_list_last_row
	state._md_list_last_row = row
	local newline = last_row ~= nil and row > last_row

	-- Not a newline: handle indent adjustment and ordered list edits
	if not newline then
		local last_gen = state._md_list_last_generated_row
		if last_gen == row and row > 0 then
			local prev = get_line(buf, row - 1)
			if not either_blocked(line, prev) then
				adjust_unordered_indent(buf, row, line, prev, state)
			end
		end
		if row >= 0 then
			local prev = row > 0 and get_line(buf, row - 1) or nil
			if not prev or not either_blocked(line, prev) then
				adjust_ordered_on_edit(buf, row, line, prev or "")
			end
		end
		state._md_list_guard = false
		return
	end

	-- Newline: only proceed if current line is blank
	if not is_empty(line) or row <= 0 then
		state._md_list_guard = false
		return
	end

	local prev = get_line(buf, row - 1)
	if either_blocked(line, prev) then
		state._md_list_guard = false
		return
	end

	-- Second newline on an empty list item: cancel the marker (exit list)
	if cancel_empty_list_item_on_second_newline(buf, row, prev, state) then
		state._md_list_guard = false
		return
	end

	-- Try ordered list first
	if handle_ordered_newline(buf, row, prev, state) then
		if row > 1 then
			local prev2 = get_line(buf, row - 2)
			if not either_blocked(prev, prev2) then
				adjust_ordered_on_edit(buf, row - 1, prev, prev2)
			end
		end
		state._md_list_guard = false
		return
	end

	-- Try task list
	if handle_task_list_newline(buf, row, line, prev, state) then
		state._md_list_guard = false
		return
	end

	-- Try unordered list
	if handle_unordered_newline(buf, row, line, prev, state) then
		state._md_list_guard = false
		return
	end

	state._md_list_guard = false
end

-- ====================================================================
-- Normal-mode "o/O" Handling
-- ====================================================================

---@param buf integer
---@param row integer
local function handle_insert_enter(buf, row)
	local line = get_line(buf, row)
	if row < 0 then
		return
	end

	-- Handle empty line: insert new list item
	if is_empty(line) then
		local prev = get_line(buf, row - 1)
		if not is_list_item(prev) then
			return
		end

		-- Join the implicit change from "o/O" with our auto-insert, so undo works as expected.
		pcall(vim.cmd, "undojoin")

		-- Force newline detection
		vim.b[buf]._md_list_last_row = row - 1
		md_bullets(buf)

		-- Move cursor to end of generated line
		vim.schedule(function()
			if api.nvim_get_current_buf() ~= buf then
				return
			end
			local cur = api.nvim_win_get_cursor(0)[1] - 1
			if cur ~= row then
				return
			end
			local new_line = get_line(buf, row)
			api.nvim_win_set_cursor(0, { row + 1, #new_line })
		end)
		return
	end
end

---@param buf integer
---@param row integer
local function renumber_ordered_after_deletion(buf, row)
	local line = get_line(buf, row)
	if row < 0 then
		return
	end

	-- Trigger when numbering jumps (current > prev + 1), indicating rows were deleted
	local cur_indent, cur_num, cur_delim = parse_ordered(line)
	if cur_num then
		local prev = row > 0 and get_line(buf, row - 1) or ""
		local prev_indent, prev_num, prev_delim = parse_ordered(prev)

		if prev_num and prev_indent == cur_indent and prev_delim == cur_delim then
			local expected = tonumber(prev_num) + 1
			local actual = tonumber(cur_num)

			-- Only renumber if there's a gap, not if just slightly off
			if actual > expected then
				-- Use undojoin to merge with the delete operation (must be immediate; don't debounce).
				pcall(vim.cmd, "undojoin")
				renumber_ordered(buf, row, cur_indent, cur_delim, expected)
			end
		end
	end
end

-- ====================================================================
-- Buffer Setup
-- ====================================================================

local function debounce(buf, fn)
	local timer = debounce_timers[buf]
	if timer then
		timer:stop()
		timer:close()
	end
	debounce_timers[buf] = vim.defer_fn(function()
		debounce_timers[buf] = nil
		fn()
	end, DEBOUNCE_MS)
end

---@param buf integer
local function setup_buf(buf)
	local state = vim.b[buf]
	if state._md_bullets_setup then
		return
	end
	state._md_bullets_setup = true

	api.nvim_create_autocmd("InsertEnter", {
		group = augroup,
		buffer = buf,
		callback = function(opts)
			if api.nvim_get_current_buf() == opts.buf then
				local row = api.nvim_win_get_cursor(0)[1] - 1
				vim.b[buf]._md_list_last_row = row
				handle_insert_enter(buf, row)
			end
		end,
	})

	api.nvim_create_autocmd("TextChangedI", {
		group = augroup,
		buffer = buf,
		callback = function(opts)
			debounce(opts.buf, function()
				md_bullets(opts.buf)
			end)
		end,
	})

	api.nvim_create_autocmd("TextChanged", {
		group = augroup,
		buffer = buf,
		callback = function(opts)
			-- Important: do NOT debounce here, otherwise "undojoin" can't merge with the delete
			-- and undo will feel broken (autocmds will re-apply numbering after undo).
			local row = api.nvim_win_get_cursor(0)[1] - 1
			renumber_ordered_after_deletion(opts.buf, row)
		end,
	})
end

-- ====================================================================
-- Entry Point
-- ====================================================================

api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "markdown",
	callback = function(opts)
		setup_buf(opts.buf)
	end,
})
