local utils = require("liu.utils")

vim.api.nvim_set_hl(0, "DebugLine", { link = "CursorLine", default = true })
local signs = {
	DapStopped = { text = "", texthl = "ModeMsg", numhl = "ModeMsg", linehl = "ModeMsg" },
	DapLogPoint = { text = "", texthl = "Tag", numhl = "Tag", linehl = "Tag" },
	DapBreakpoint = { text = "", texthl = "Debug", numhl = "Debug", linehl = "DebugLine" },
	DapBreakpointCondition = { text = "", texthl = "Conditional", numhl = "Conditional", linehl = "Conditional" },
	DapBreakpointRejected = { text = "", texthl = "ErrorMsg", numhl = "ErrorMsg", linehl = "" },
}
for name, opt in pairs(signs) do
	vim.fn.sign_define(name, opt)
end

return {
	{
		"mfussenegger/nvim-dap",
		-- integrates with: vim-flagship (status via DAPStopped autocmd in ui.lua)
		keys = {
			{ "dcc", "<cmd>lua require('dap').continue()<cr>", desc = "Continue debugging" },
			{ "dcb", "<cmd>lua require('dap').toggle_breakpoint()<cr>", desc = "Toggle breakpoint" },
			{ "dcB", "<cmd>lua require('dap').clear_breakpoints()<cr>", desc = "Clear breakpoints" },
			{
				"dcC",
				function()
					local ok, condition = pcall(vim.fn.input, { prompt = "Breakpoint Condition: " })
					if ok and condition and condition ~= "" then
						require("dap").toggle_breakpoint(condition, nil, nil, true)
					end
				end,
				desc = "Conditional breakpoint",
			},
			{
				"dcL",
				function()
					local ok, logpoint = pcall(vim.fn.input, { prompt = "Log point message: " })
					if ok and logpoint and logpoint ~= "" then
						require("dap").toggle_breakpoint(nil, nil, logpoint, true)
					end
				end,
				desc = "Log point",
			},
			{
				"dcr",
				[[:lua require("dap").repl.toggle({ height = 12, winfixheight = true })<CR>]],
				desc = "Toggle REPL",
			},
		},
		cmd = {
			"DapContinue",
			"DapToggleBreakpoint",
			"DapToggleRepl",
			"DapBreakpoints",
		},
		config = function(self, opts)
			require("liu.dap")

			vim.api.nvim_create_user_command("DapBreakpoints", function(args)
				require("dap").list_breakpoints(true)
			end, {})
		end,
	},
	{
		"igorlfs/nvim-dap-view",
		-- depends on: nvim-dap
		opts = {
			winbar = {
				default_section = "repl",
			},
		},
		cmd = "DapViewToggle",
		keys = { { "dc<cr>", "<cmd>DapViewToggle<cr>", desc = "Toggle DAP view" } },
	},
	{
		"Jorenar/nvim-dap-disasm",
		-- depends on: nvim-dap
		opts = {
			winbar = false,
		},
		cmd = "DapDisasm",
	},
}
