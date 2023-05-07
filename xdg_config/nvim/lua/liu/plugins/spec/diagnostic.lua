return {
	{
		"folke/trouble.nvim",
		event = "VeryLazy",
		enabled = false,
		config = function()
			require("trouble").setup({})
		end,
	},
}
