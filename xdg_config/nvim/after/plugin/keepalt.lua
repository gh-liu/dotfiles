-- Preserve each window's alternate buffer while temporarily visiting special buffers.
-- For example, A (# = B) -> special (# = B) -> A (# = B). The saved alternate
-- buffer is restored when entering the special buffer and on the first return to A.
--
-- Snapshot normal-buffer state on BufEnter: Neovim updates the alternate buffer
-- before BufLeave runs, so BufLeave can no longer observe the previous value.

local api = vim.api
local group = api.nvim_create_augroup("liu/keepalt", { clear = true })
local normal_buffers = {}
local active_buffers = {}

-- Add new special-buffer predicates here.
local function is_special(buf)
	return vim.b[buf].fugitive_type ~= nil or vim.bo[buf].filetype == "directory"
end

local function restore_altbuffer(buf)
	if not api.nvim_buf_is_valid(buf) then
		return
	end
	local name = api.nvim_buf_get_name(buf)
	if name ~= "" then
		vim.cmd.balt({ args = { name } })
	end
end

api.nvim_create_autocmd("BufEnter", {
	group = group,
	callback = function(data)
		local win = api.nvim_get_current_win()
		local active = active_buffers[win]
		if active and data.buf == active.original then
			restore_altbuffer(active.alternate)
			active_buffers[win] = nil
			return
		end

		if active then
			return
		end
		if not is_special(data.buf) then
			normal_buffers[win] = { original = data.buf, alternate = vim.fn.bufnr("#") }
			return
		end
		local normal = normal_buffers[win]
		if normal and normal.alternate > 0 then
			active_buffers[win] = normal
			restore_altbuffer(normal.alternate)
		end
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
