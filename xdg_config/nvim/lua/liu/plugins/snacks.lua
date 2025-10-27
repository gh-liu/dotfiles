local input_keys = {
	["<c-j>"] = { "history_forward", mode = { "i" } },
	["<c-k>"] = { "history_back", mode = { "i" } },
	["<c-a>"] = { "<c-o>I", mode = { "i" }, expr = true },
}

return {
	"folke/snacks.nvim",
	opts = {
		-- :h snacks.nvim-picker-config
		picker = {
			enabled = true,
			win = {
				input = { keys = input_keys, wo = { stl = "%y" } },
				list = { wo = { stl = "%y" } },
				preview = { wo = { stl = "%y" } },
			},
		},
		-- ===========================
		bigfile = { enabled = false },
		dashboard = { enabled = false },
		explorer = { enabled = false },
		indent = { enabled = false },
		input = { enabled = false },
		notifier = { enabled = false },
		quickfile = { enabled = false },
		scope = { enabled = false },
		scroll = { enabled = false },
		statuscolumn = { enabled = false },
		words = { enabled = false },
	},
	init = function()
		local map = function(op, cmd, opts)
			opts = opts or {}
			vim.keymap.set("n", "<leader>s" .. op, function()
				require("snacks").picker(cmd, opts)
			end)
		end
		map("b", "buffers")
		map("d", "diagnostics_buffer")
		map("f", "files")
		map("g", "live_grep")
		map("h", "help")
		map("m", "marks")
		map("s", "lsp_symbols")
		map("w", "grep_word")

		vim.keymap.set("n", "<leader>;", function()
			require("snacks").picker("commands", { layout = "select" })
		end)

		vim.api.nvim_set_hl(0, "SnacksPickerDir", { link = "Directory" })
	end,
}
