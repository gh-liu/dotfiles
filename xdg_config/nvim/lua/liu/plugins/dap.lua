local signs = {
	DapStopped = { text = "", texthl = "MoreMsg", numhl = "MoreMsg", linehl = "" },
	DapLogPoint = { text = "", texthl = "Tag", numhl = "Tag", linehl = "" },
	DapBreakpoint = { text = "", texthl = "Debug", numhl = "Debug", linehl = "" },
	DapBreakpointCondition = { text = "", texthl = "Conditional", numhl = "Conditional" },
	DapBreakpointRejected = { text = "", texthl = "ErrorMsg", numhl = "ErrorMsg", linehl = "" },
}
for name, opt in pairs(signs) do
	vim.fn.sign_define(name, opt)
end

return {
	{
		"mfussenegger/nvim-dap",
		keys = {
			{ "dcc", [[:lua require("dap").continue()<CR>]] },
			{ "dcb", [[:lua require("dap").toggle_breakpoint()<CR>]] },
			{
				"dcB",
				function()
					local ok, condition = pcall(vim.fn.input, { prompt = "Breakpoint Condition: " })
					if ok then
						if condition and condition ~= "" then
							require("dap").toggle_breakpoint(condition, nil, nil, true)
						end
					end
				end,
			},
			{
				"dcL",
				function()
					local ok, logpoint = pcall(vim.fn.input, { prompt = "Log point message: " })
					if ok then
						if logpoint and logpoint ~= "" then
							require("dap").toggle_breakpoint(nil, nil, logpoint, true)
						end
					end
				end,
			},
			-- { "dcr", [[:lua require("dap").repl.toggle({ height = 12, winfixheight = true })<CR>]] },
		},
		cmd = {
			"DapContinue",
			"DapToggleBreakpoint",
			"DapToggleRepl",
			"DapBreakpoints",
		},
		config = function(self, opts)
			require("liu.dap")

			-- local dap = require("dap")
			vim.api.nvim_create_user_command("DapBreakpoints", function(args)
				require("dap").list_breakpoints(true)
			end, {})

			-- https://github.com/mfussenegger/nvim-dap/pull/1237
			-- which always load `.vscode/launch.json`
			-- require("dap.ext.vscode").load_launchjs()
		end,
	},
}
