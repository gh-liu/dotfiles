local dap = {
	{
		"mfussenegger/nvim-dap",
		-- event = "VeryLazy",
		keys = { { "<C-s>" } }, -- invoke hydra for dap
		cmd = { "DapContinue", "DapToggleBreakpoint" },
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"jbyuki/one-small-step-for-vimkind",
		},
		config = function()
			require("liu.dap")
		end,
	},
	-- {
	-- 	"rcarriga/nvim-dap-ui",
	-- 	event = "VeryLazy",
	-- 	config = function() end,
	-- },
	-- {
	-- 	"jbyuki/one-small-step-for-vimkind",
	-- 	event = "VeryLazy",
	-- 	config = function() end,
	-- },
}

return dap
