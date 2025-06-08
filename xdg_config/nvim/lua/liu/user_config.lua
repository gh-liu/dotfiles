return {
	borders = vim.o.winborder or { "┌", "─", "┐", "│", "┘", "─", "└", "│" },
	icons = {
		diagnostics = {
			-- ERROR = "E",
			-- WARN = "W",
			-- INFO = "I",
			-- HINT = "H",
			ERROR = "",
			WARN = "",
			INFO = "",
			HINT = "",
		},
		fold = { "", "" },
		directory = " ",
		bug = "",
		git = "",
	},
}
