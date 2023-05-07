local dap = {
	{
		"mfussenegger/nvim-dap",
		event = "VeryLazy",
		config = function()
			require("liu.dap")
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		event = "VeryLazy",
		config = function() end,
	},
	{
		"jbyuki/one-small-step-for-vimkind",
		event = "VeryLazy",
		config = function() end,
	},
}

return dap
