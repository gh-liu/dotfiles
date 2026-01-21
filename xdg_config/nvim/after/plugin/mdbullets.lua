local api = vim.api

local augroup = api.nvim_create_augroup("liu/mdbullets", { clear = true })

-- Lua-side debounce timers (cannot be stored in vim.b).
local debounce_timers = {}

--[[ Markdown list helpers

Scenarios covered:
1) Insert-mode newline on unordered list => auto insert "-/*/+" with indent-aware rotation.
2) Insert-mode newline on ordered list   => auto insert next number and renumber following siblings.
3) After newline, user Tab/Shift-Tab      => adjust bullet on the just-generated empty line.
4) Edit/delete ordered list numbers       => renumber forward when there is a next sibling.
5) Normal-mode "o/O"                      => handled on InsertEnter/TextChanged.

Safeguards:
- Only active for markdown buffers.
- Only act on blank new lines.
- Ordered renumbering stops at empty lines, skips deeper indent blocks, max 200 lines.
]]

local bullets = { "-", "*", "+" }

local function next_bullet(b)
	for i, v in ipairs(bullets) do
		if v == b then
			return bullets[(i % #bullets) + 1]
		end
	end
	return "-"
end

local function prune_stack_to(stack, indent_len)
	while #stack > 0 and stack[#stack].indent > indent_len do
		table.remove(stack)
	end
end

local function set_level(stack, indent_len, bullet)
	prune_stack_to(stack, indent_len)
	if #stack == 0 or stack[#stack].indent < indent_len then
		table.insert(stack, { indent = indent_len, bullet = bullet })
	else
		stack[#stack].bullet = bullet
	end
end

local function get_level_bullet(stack, indent_len)
	prune_stack_to(stack, indent_len)
	if #stack > 0 and stack[#stack].indent == indent_len then
		return stack[#stack].bullet
	end
end

-- Decide which bullet to use based on indent changes.
-- Same indent => reuse; deeper indent => rotate; shallower => reuse last known level.
local function compute_unordered_bullet(stack, prev_len, cur_len, prev_bullet)
	if #stack == 0 then
		set_level(stack, prev_len, prev_bullet)
	end

	local use
	if cur_len > prev_len then
		use = next_bullet(prev_bullet)
	else
		use = get_level_bullet(stack, cur_len) or prev_bullet
	end

	set_level(stack, cur_len, use)
	return use
end

-- Renumber ordered list items forward within the same indent block.
-- Stops on empty line; skips deeper indent blocks; limits scan for safety.
local function renumber_forward(buf, start_row, indent, delim, start_num)
	local i = start_row
	local num = start_num
	local max_lines = 200
	local scanned = 0
	while true do
		if scanned >= max_lines then
			break
		end
		local line = api.nvim_buf_get_lines(buf, i, i + 1, false)[1]
		if not line then
			break
		end

		-- Stop at empty line (breaks list continuity).
		if line:match("^%s*$") then
			break
		end

		-- Skip deeper indent blocks (e.g. nested lists/code).
		local line_indent = line:match("^(%s*)") or ""
		if #line_indent > #indent then
			i = i + 1
			scanned = scanned + 1
			goto continue
		end

		local ind, _, line_delim = line:match("^(%s*)(%d+)([%.%)、])%s+")
		if not ind or ind ~= indent or line_delim ~= delim then
			break
		end

		local rest = line:gsub("^%s*%d+[%.%)、]%s+", "")
		local new_line = indent .. num .. delim .. " " .. rest
		if new_line ~= line then
			api.nvim_buf_set_lines(buf, i, i + 1, false, { new_line })
		end

		num = num + 1
		i = i + 1
		scanned = scanned + 1
		::continue::
	end
end

-- Replace current line and keep cursor at line end.
local function set_line_and_cursor(buf, row, text)
	api.nvim_buf_set_lines(buf, row, row + 1, false, { text })
	api.nvim_win_set_cursor(0, { row + 1, #text })
end

-- Scenario: previous line is unordered list item, and current line is empty.
-- Generates the next list prefix with indent-aware bullet selection.
local function handle_unordered_newline(buf, row, line, prev, state)
	local prev_indent, prev_bullet = prev:match("^(%s*)([-*+])%s+")
	if not prev_bullet then
		return false
	end

	local cur_indent = line:match("^(%s*)") or ""
	local stack = state._md_list_indent_stack or {}
	local use = compute_unordered_bullet(stack, #prev_indent, #cur_indent, prev_bullet)

	state._md_list_indent_stack = stack
	set_line_and_cursor(buf, row, cur_indent .. use .. " ")
	state._md_list_last_generated_row = row
	return true
end

-- Scenario: previous line is ordered list item, and current line is empty.
-- Generates next number and fixes following siblings.
local function handle_ordered_newline(buf, row, prev, state)
	local indent, num, delim = prev:match("^(%s*)(%d+)([%.%)、])%s+")
	if not num then
		return false
	end

	local nextnum = tonumber(num) + 1
	local text = indent .. nextnum .. delim .. " "
	set_line_and_cursor(buf, row, text)
	renumber_forward(buf, row + 1, indent, delim, nextnum + 1)
	state._md_list_last_generated_row = row
	return true
end

-- Scenario: user changes indent (Tab/Shift-Tab) on the just-generated empty bullet line.
-- We recompute bullet based on new indent without creating new items.
local function adjust_unordered_on_indent_change(buf, row, line, prev, state)
	local cur_indent, cur_bullet = line:match("^(%s*)([-*+])%s*$")
	if not cur_bullet then
		return false
	end

	local prev_indent, prev_bullet = prev:match("^(%s*)([-*+])%s+")
	if not prev_bullet then
		return false
	end

	local stack = state._md_list_indent_stack or {}
	local use = compute_unordered_bullet(stack, #prev_indent, #cur_indent, prev_bullet)
	state._md_list_indent_stack = stack

	local text = cur_indent .. use .. " "
	if text ~= line then
		set_line_and_cursor(buf, row, text)
	end
	return true
end

-- Scenario: user deletes or edits ordered list numbers on the same line.
-- If current line is ordered and previous sibling exists, renumber forward.
local function adjust_ordered_on_edit(buf, row, line, prev)
	local cur_indent, cur_num, cur_delim = line:match("^(%s*)(%d+)([%.%)、])%s+")
	if not cur_num or row <= 0 then
		return false
	end

	local prev_indent, prev_num, prev_delim = prev:match("^(%s*)(%d+)([%.%)、])%s+")
	if not prev_num or prev_indent ~= cur_indent or prev_delim ~= cur_delim then
		return false
	end

	-- Only renumber if there is a following ordered sibling; avoid forcing numbering
	-- when the next line is not an ordered list item.
	local next_line = api.nvim_buf_get_lines(buf, row + 1, row + 2, false)[1] or ""
	local next_indent, _, next_delim = next_line:match("^(%s*)(%d+)([%.%)、])%s+")
	if not next_indent or next_indent ~= cur_indent or next_delim ~= cur_delim then
		return false
	end

	renumber_forward(buf, row, cur_indent, cur_delim, tonumber(prev_num) + 1)
	return true
end

local function is_task_list(line)
	return line:match("^%s*[-*+]%s+%[[ xX]%]%s+")
end

local function is_blocked(line)
	return line:match("^%s*```") or line:match("^%s*>")
end

local function md_bullets(buf)
	local state = vim.b[buf]
	if state._md_list_guard then
		return
	end
	state._md_list_guard = true

	if api.nvim_get_current_buf() ~= buf then
		state._md_list_guard = false
		return
	end

	local row = api.nvim_win_get_cursor(0)[1] - 1
	local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""

	-- Rule #1: only treat as "newline happened" when row increased.
	local last_row = state._md_list_last_row
	state._md_list_last_row = row
	local newline = (last_row ~= nil and row > last_row)

	-- Scenario: user presses <Tab>/<S-Tab> after newline to change indent.
	-- We only adjust bullets on the last auto-generated empty list line.
	if not newline then
		local last_gen_row = state._md_list_last_generated_row
		if last_gen_row ~= nil and row == last_gen_row and row > 0 then
			local prev = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
			if is_blocked(line) or is_blocked(prev) then
				state._md_list_guard = false
				return
			end
			adjust_unordered_on_indent_change(buf, row, line, prev, state)
		end
		if row > 0 then
			local prev = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
			if not is_blocked(line) and not is_blocked(prev) then
			adjust_ordered_on_edit(buf, row, line, prev)
			end
		end
		state._md_list_guard = false
		return
	end

	-- Rule #2: only generate a new item when the new line is blank (may contain autoindent spaces).
	if not line:match("^%s*$") or row <= 0 then
		state._md_list_guard = false
		return
	end

	local prev = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
	if is_blocked(line) or is_blocked(prev) then
		state._md_list_guard = false
		return
	end

	-- Scenario: previous line is an "empty list item" -> stop list (do nothing).
	if prev:match("^%s*[-*+]%s*$") or prev:match("^%s*%d+%.%s*$") then
		state._md_list_guard = false
		return
	end

	-- Scenario: ordered list -> auto increment and renumber following siblings.
	if handle_ordered_newline(buf, row, prev, state) then
		-- Best-effort fix for earlier siblings in the same indent block.
		if row > 1 then
			local prev2 = api.nvim_buf_get_lines(buf, row - 2, row - 1, false)[1] or ""
			if not is_blocked(prev) and not is_blocked(prev2) then
				adjust_ordered_on_edit(buf, row - 1, prev, prev2)
			end
		end
		state._md_list_guard = false
		return
	end

	-- Scenario: unordered list -> inherit/rotate bullet based on indent.
	if is_task_list(prev) then
		local indent, prev_bullet = prev:match("^(%s*)([-*+])%s+%[[ xX]%]%s+")
		if prev_bullet then
			local cur_indent = line:match("^(%s*)") or ""
			local stack = state._md_list_indent_stack or {}
			local use = compute_unordered_bullet(stack, #indent, #cur_indent, prev_bullet)
			state._md_list_indent_stack = stack
			set_line_and_cursor(buf, row, cur_indent .. use .. " [ ] ")
			state._md_list_last_generated_row = row
			state._md_list_guard = false
			return
		end
	end
	if handle_unordered_newline(buf, row, line, prev, state) then
		state._md_list_guard = false
		return
	end

	state._md_list_guard = false
end

-- Buffer-local setup for markdown only.
local function is_list_prev(prev)
	return prev:match("^%s*[-*+]%s+") or prev:match("^%s*%d+%.%s+")
end

local function try_handle_normal_insert(buf, row)
	local line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
	if row <= 0 or not line:match("^%s*$") then
		return
	end

	local prev = api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
	if not is_list_prev(prev) then
		return
	end

	-- Force newline detection for normal-mode insertions.
	vim.b[buf]._md_list_last_row = row - 1
	md_bullets(buf)
	vim.schedule(function()
		if api.nvim_get_current_buf() ~= buf then
			return
		end
		local cur = api.nvim_win_get_cursor(0)[1] - 1
		if cur ~= row then
			return
		end
		local new_line = api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
		api.nvim_win_set_cursor(0, { row + 1, #new_line })
	end)
end

local function setup_buf(buf)
	local state = vim.b[buf]
	if state._md_bullets_setup then
		return
	end
	state._md_bullets_setup = true

	-- Initialize last_row so the very first newline can be detected.
	api.nvim_create_autocmd("InsertEnter", {
		group = augroup,
		buffer = buf,
		callback = function(opts)
			if api.nvim_get_current_buf() == opts.buf then
				local row = api.nvim_win_get_cursor(0)[1] - 1
				vim.b[buf]._md_list_last_row = row
				try_handle_normal_insert(buf, row)
			end
		end,
	})

	local function debounce_call(fn)
		local timer = debounce_timers[buf]
		if timer then
			timer:stop()
			timer:close()
			debounce_timers[buf] = nil
		end
		debounce_timers[buf] = vim.defer_fn(function()
			debounce_timers[buf] = nil
			fn()
		end, 80)
	end

	api.nvim_create_autocmd("TextChangedI", {
		group = augroup,
		buffer = buf,
		callback = function(opts)
			debounce_call(function()
				md_bullets(opts.buf)
			end)
		end,
	})

	-- Handle normal-mode "o/O": the new line is created before Insert mode.
	api.nvim_create_autocmd("TextChanged", {
		group = augroup,
		buffer = buf,
		callback = function(opts)
			local row = api.nvim_win_get_cursor(0)[1] - 1
			debounce_call(function()
				try_handle_normal_insert(opts.buf, row)
			end)
		end,
	})
end

api.nvim_create_autocmd("FileType", {
	group = augroup,
	pattern = "markdown",
	callback = function(opts)
		setup_buf(opts.buf)
	end,
})
