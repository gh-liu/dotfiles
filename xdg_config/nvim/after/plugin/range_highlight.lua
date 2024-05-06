if true then
	return
end

local api = vim.api
local fn = vim.fn

local M = {
	ns = nil,
	start_line = 0,
	end_line = 0,
}

local name = "liu/range_highlight"

M.setup = function()
	M.ns = api.nvim_create_namespace(name)
	local g = api.nvim_create_augroup(name, { clear = true })

	api.nvim_create_autocmd("CmdlineChanged", {
		pattern = ":",
		group = g,
		callback = function(ev)
			-- local cmdtype = ev.match
			-- -- cmdtype = fn.getcmdtype()
			-- if cmdtype ~= ":" then
			-- 	return
			-- end

			local text = fn.getcmdline()

			local ok, val = pcall(api.nvim_parse_cmd, text, {})
			if not ok then
				ok, val = pcall(api.nvim_parse_cmd, text .. "p", {})
			end

			if ok and val.range and #val.range > 0 then
				-- vim.print(val.range)
				if M.start_line > 0 and M.end_line > 0 then
					M:cleanup()
				end
				M.start_line = val.range[1]
				M.end_line = val.range[1]
				if #val.range == 2 then
					M.end_line = val.range[2]
				end

				M:add_highlight()
			end
		end,
	})

	api.nvim_create_autocmd("CmdlineLeave", {
		pattern = ":",
		group = g,
		callback = function(ev)
			M:cleanup()
		end,
	})
end

function M:cleanup()
	api.nvim_buf_clear_namespace(0, M.ns, 0, -1)
	M.start_line = 0
	M.end_line = 0
end

function M:add_highlight()
	vim.highlight.range(0, M.ns, "Visual", { M.start_line - 1, 0 }, { M.end_line, 0 }, { "V", false })
	vim.cmd("redraw")
end

M.setup()
