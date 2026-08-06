-- Preserve each window's alternate buffer while temporarily visiting special buffers.
-- For example, A (# = B) -> special (# = B) -> A (# = B). The saved alternate
-- buffer is restored when entering the special buffer and on the first return to A.
-- Entering another normal buffer instead cancels the pending restoration.
--
-- Snapshot normal-buffer state on BufEnter: Neovim updates the alternate buffer
-- before BufLeave runs, so BufLeave can no longer observe the previous value.
-- Only named, listed buffers are restored; :balt would otherwise relist a deleted
-- buffer. Alternate changes made by :balt without an observed event cannot be tracked.

local api = vim.api
local group = api.nvim_create_augroup("liu/keepalt", { clear = true })
local normal_buffers = {}
local active_buffers = {}

-- Add new special-buffer predicates here.
local function is_special(buf)
	return vim.b[buf].fugitive_type ~= nil or vim.bo[buf].filetype == "directory"
end

local function can_restore(buf)
	return buf > 0 and api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted and api.nvim_buf_get_name(buf) ~= ""
end

local function snapshot_is_valid(snapshot)
	return api.nvim_buf_is_valid(snapshot.original) and can_restore(snapshot.alternate)
end

local function restore_altbuffer(buf)
	if not can_restore(buf) then
		return false
	end
	vim.cmd.balt({ args = { api.nvim_buf_get_name(buf) } })
	return true
end

local function remember_normal_buffer(win, buf)
	normal_buffers[win] = { original = buf, alternate = vim.fn.bufnr("#") }
end

api.nvim_create_autocmd("BufEnter", {
	group = group,
	callback = function(data)
		local win = api.nvim_get_current_win()
		local active = active_buffers[win]
		local special = is_special(data.buf)
		if active and not snapshot_is_valid(active) then
			active_buffers[win] = nil
			normal_buffers[win] = nil
			active = nil
		end
		if active and data.buf == active.original then
			restore_altbuffer(active.alternate)
			active_buffers[win] = nil
			return
		end

		if active then
			if special then
				restore_altbuffer(active.alternate)
				return
			end
			active_buffers[win] = nil
		end
		if not special then
			remember_normal_buffer(win, data.buf)
			return
		end
		local normal = normal_buffers[win]
		if normal and snapshot_is_valid(normal) and restore_altbuffer(normal.alternate) then
			active_buffers[win] = normal
		else
			normal_buffers[win] = nil
		end
	end,
})

api.nvim_create_autocmd("WinEnter", {
	group = group,
	callback = function()
		local win = api.nvim_get_current_win()
		local buf = api.nvim_get_current_buf()
		if not active_buffers[win] and not is_special(buf) then
			remember_normal_buffer(win, buf)
		end
	end,
})

local function seed_normal_buffers(reset)
	if reset then
		normal_buffers = {}
		active_buffers = {}
	end
	for _, win in ipairs(api.nvim_list_wins()) do
		api.nvim_win_call(win, function()
			local buf = api.nvim_get_current_buf()
			if not active_buffers[win] and not is_special(buf) then
				remember_normal_buffer(win, buf)
			end
		end)
	end
end

api.nvim_create_autocmd({ "VimEnter", "SessionLoadPost" }, {
	group = group,
	callback = function(data)
		seed_normal_buffers(data.event == "SessionLoadPost")
	end,
})

api.nvim_create_autocmd("WinClosed", {
	group = group,
	callback = function(data)
		local win = tonumber(data.match)
		normal_buffers[win] = nil
		active_buffers[win] = nil
	end,
})
