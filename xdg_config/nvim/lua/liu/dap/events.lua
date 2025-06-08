local api = vim.api

local dap = require("dap")
-- https://microsoft.github.io/debug-adapter-protocol/specification#Requests
dap.listeners.before["initialize"]["user"] = function(session, error, resp, req_body, req_id)
	-- cmd([[doautocmd User DAPInitialize]])
	local pattern = "DAPInitialize"
	api.nvim_exec_autocmds("User", { pattern = pattern })
end

-- https://microsoft.github.io/debug-adapter-protocol/specification#Events
dap.listeners.before["event_initialized"]["user"] = function(session, _)
	-- cmd([[doautocmd User DAPInitialized]])
	local pattern = "DAPInitialized"
	api.nvim_exec_autocmds("User", { pattern = pattern })
end

dap.listeners.after["event_stopped"]["user"] = function(session, event_body)
	-- cmd([[doautocmd User DAPStopped]])
	local pattern = "DAPStopped"
	api.nvim_exec_autocmds("User", { pattern = pattern, data = event_body })
end

dap.listeners.after["event_exited"]["user"] = function(session, _)
	-- cmd([[doautocmd User DAPExited]])
	local pattern = "DAPExited"
	api.nvim_exec_autocmds("User", { pattern = pattern })
end

dap.listeners.after["event_terminated"]["user"] = function(session, _)
	-- cmd([[doautocmd User DAPTerminated]])
	local pattern = "DAPTerminated"
	api.nvim_exec_autocmds("User", { pattern = pattern })
end
