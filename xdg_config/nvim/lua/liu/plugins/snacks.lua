local input_keys = {
	["<c-j>"] = { "history_forward", mode = { "i" } },
	["<c-k>"] = { "history_back", mode = { "i" } },
	["<c-a>"] = { "<c-o>I", mode = { "i" }, expr = true },
}

local mypickers = {}
mypickers.args = {
	finder = function(opts, ctx)
		local args = vim.fn.argv()
		---@type snacks.picker.finder.Item[]
		local items = vim.iter(args)
			:map(function(arg)
				local buf = vim.fn.bufnr(arg)
				return {
					buf = buf,
					name = vim.api.nvim_buf_get_name(buf),
					buftype = vim.bo[buf].buftype,
					filetype = vim.bo[buf].filetype,
					file = arg,
					text = arg,
					-- info = vim.fn.getbufinfo(buf)[1],
				}
			end)
			:totable()
		return function(cb)
			for _, item in ipairs(items) do
				cb(item)
			end
		end
	end,
	actions = {
		argdelete = function(self, item, action)
			self.preview:reset()

			vim.cmd.argdelete(item.file)

			self.list:set_selected()
			self.list:set_target()
			self:find()
		end,
	},
}

-- @need-install: cargo install fd-find
-- @need-install: cargo install ripgrep
return {
	"folke/snacks.nvim",
	priority = 1000,
	opts = {
		-- :h snacks.nvim-picker-config
		picker = {
			enabled = true,
			win = {
				input = { keys = input_keys, wo = {} },
				list = { wo = {} },
				preview = { wo = {} },
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
		vim.ui.select = function(...)
			require("snacks.picker.select").select(...)
		end

		local map = function(op, cmd, opts)
			opts = opts or {}
			vim.keymap.set("n", "<leader>s" .. op, function()
				require("snacks").picker(cmd, opts)
				-- require("snacks.picker")[cmd](opts)
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
		map("o", "recent", { filter = { cwd = true } })

		vim.keymap.set("n", "<leader>sa", function()
			require("snacks").picker({
				title = "Args",
				format = "file",
				finder = mypickers.args.finder,
				actions = mypickers.args.actions,
				win = {
					input = {
						keys = {
							["<c-x>"] = { "argdelete", mode = { "n", "i" } },
						},
					},
				},
			})
		end)

		vim.keymap.set("n", "<leader>;", function()
			require("snacks").picker("commands", { layout = "select" })
		end)

		vim.api.nvim_set_hl(0, "SnacksPickerDir", { link = "Directory" })
	end,
}
