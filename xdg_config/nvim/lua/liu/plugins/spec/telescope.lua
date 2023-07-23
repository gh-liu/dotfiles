return {
	{
		"ThePrimeagen/harpoon",
		-- event = "VeryLazy",
		keys = {
			{
				"<C-y>",
				function()
					local mark = require("harpoon.mark")
					mark.add_file()
				end,
			},
			{
				"<C-e>",
				function()
					local ui = require("harpoon.ui")
					ui.toggle_quick_menu()
				end,
			},
			{
				"<C-h>",
				function()
					local ui = require("harpoon.ui")
					ui.nav_prev()
				end,
			},
			{
				"<C-l>",
				function()
					local ui = require("harpoon.ui")
					ui.nav_next()
				end,
			},
		},
		config = function()
			require("harpoon").setup()
			-- local mark = require("harpoon.mark")
			-- local ui = require("harpoon.ui")
			-- vim.keymap.set("n", "<C-y>", mark.add_file)
			-- vim.keymap.set("n", "<C-e>", ui.toggle_quick_menu)
			-- vim.keymap.set("n", "<C-h>", ui.nav_prev)
			-- vim.keymap.set("n", "<C-l>", ui.nav_next)

			set_hls({ HarpoonBorder = { link = "FloatBorder" } })

			-- for i = 1, 5 do
			-- 	vim.keymap.set("n", string.format("<leader>h%s", i), function()
			-- 		ui.nav_file(i)
			-- 	end)
			-- end
		end,
	},
	{
		"nvim-telescope/telescope.nvim",
		event = "VeryLazy",
		init = function() end,
		config = function()
			local builtin = require("telescope.builtin")
			local actions = require("telescope.actions")
			local action_state = require("telescope.actions.state")

			vim.keymap.set("n", "<leader>so", builtin.oldfiles, { desc = "[S]earch recently [O]pened files" })
			vim.keymap.set("n", "<leader>sb", builtin.buffers, { desc = "[S]earch existing [B]uffers" })
			vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })

			vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
			vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })

			vim.keymap.set("n", "<leader>sm", builtin.marks, { desc = "[S]earch [M]ark" })
			vim.keymap.set("n", "<leader>sj", builtin.jumplist, { desc = "[S]et [J]umplist" })
			vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
			vim.keymap.set("n", "<leader>sr", builtin.registers, { desc = "[S]earch [R]egisters" })
			vim.keymap.set("n", "<leader>st", builtin.filetypes, { desc = "[S]et File[t]ype" })

			vim.keymap.set("n", "<leader>;", builtin.commands, { desc = "List Commands" })
			-- vim.keymap.set("n", "<leader>;", builtin.command_history, { desc = "List Commands executed recently" })

			vim.keymap.set(
				"n",
				"<leader>ds",
				"<cmd>Telescope treesitter<CR>",
				{ desc = "Lists Treesitter [D]ocument [S]ymbols in the current buffer" }
			)
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspAttachTelescopeKeymaps", { clear = true }),
				callback = function(args)
					local map = function(l, r, desc)
						vim.keymap.set("n", l, r, { buffer = args.buf, desc = desc })
					end
					map("gd", builtin.lsp_definitions, "[G]oto [D]efinition")
					map("gD", builtin.lsp_type_definitions, "[G]oto Type [D]efinition")
					map("gr", builtin.lsp_references, "[G]oto [R]eferences")
					map("gi", builtin.lsp_implementations, "[G]oto [I]mplementation")

					-- map("<leader>ds", builtin.lsp_document_symbols, "Lists LSP [D]ocument [S]ymbols in the current buffer")

					vim.keymap.set(
						"n",
						"<leader>ds",
						"<cmd>Telescope lsp_document_symbols<CR>",
						{ desc = "Lists LSP [D]ocument [S]ymbols in the current buffer" }
					)

					-- map("gI", builtin.lsp_incoming_calls, "[G]oto [I]ncomingCalls")
					-- map("gO", builtin.lsp_outgoing_calls, "[G]oto [O]utgoingCalls")
				end,
			})

			vim.api.nvim_create_autocmd("DiagnosticChanged", {
				group = vim.api.nvim_create_augroup("UserDiagnosticChangedTelescopeKeymaps", { clear = true }),
				callback = function(args)
					local map = function(l, r, desc)
						vim.keymap.set("n", l, r, { buffer = args.buf, desc = desc })
					end

					map("<leader>sd", function()
						-- builtin.diagnostics({
						-- 	severity_limit = vim.diagnostic.severity.WARN,
						-- })

						vim.ui.select({ "ALL", "ERROR", "WARN", "INFO", "HINT" }, {
							prompt = "Remove Workspace Folder",
							format_item = function(item)
								return "Filter: " .. item
							end,
						}, function(choice)
							if not choice then
								return
							end

							if choice == "ALL" then
								builtin.diagnostics()
							else
								local opts = {}
								opts.severity = choice
								builtin.diagnostics(opts)
							end
						end)
					end, "[S]earch [D]iagnostics")

					-- map("<leader>sdd", function()
					-- 	builtin.diagnostics({
					-- 		bufnr = 0,
					-- 	})
					-- end, "[S]earch [D]iagnostics of Current Buffer")
				end,
			})

			local function delete_history_command(prompt_bufnr)
				local current_picker = action_state.get_current_picker(prompt_bufnr)
				local function _1_(selection)
					local select = selection[1]
					-- vim.pretty_print(select)
					local esc = vim.fn.escape(select, "^$.*/\\[]~")
					local pattern = string.format("^%s$", esc)
					vim.fn.histdel("cmd", pattern)
					return true
				end
				return current_picker:delete_selection(_1_)
			end

			local function clear_mark(prompt_bufnr)
				vim.print(prompt_bufnr)
				local current_picker = action_state.get_current_picker(prompt_bufnr)
				local function _1_(selection)
					local value = selection.value
					local m = string.sub(value, 1, 1)
					local cmd = string.format("delmarks %s", m)
					vim.print(cmd)
					return true
				end
				return current_picker:delete_selection(_1_)
			end

			require("telescope").setup({
				defaults = {
					mappings = {
						i = {
							["<ESC>"] = actions.close,
							["<c-l>"] = false,
							-- ["<c-q>"] = false,
							["<c-j>"] = actions.move_selection_next,
							["<c-k>"] = actions.move_selection_previous,
							["<C-n>"] = actions.cycle_history_next,
							["<C-p>"] = actions.cycle_history_prev,
						},
						n = {
							["<ESC>"] = actions.close,
							["<c-l>"] = false,
							["<c-q>"] = false,
							["?"] = false,
							["g?"] = actions.which_key,
							-- ["<c-j>"] = actions.move_selection_next,
							-- ["<c-k>"] = actions.move_selection_previous,
						},
					},
					layout_config = {
						horizontal = { prompt_position = "top", preview_width = 0.6, results_width = 0.8 },
						vertical = { mirror = false },
						width = 0.8,
						height = 0.8,
						preview_cutoff = 120,
					},
					-- history = { path = "~/.local/share/nvim/databases/telescope_history.sqlite3", limit = 100 },
					sorting_strategy = "ascending",
					winblend = 5,
					path_display = { "truncate" },
					file_ignore_patterns = { "target/", ".git/" },
				},
				pickers = {
					buffers = { mappings = { [{ "i", "n" }] = { ["<c-d>"] = actions.delete_buffer } } },
					find_files = {
						-- find_command = { "fdfind", "--strip-cwd-prefix", "-I", "-H", "-E", ".git", "-t", "f" },
						hidden = true,
						no_ignore = true,
					},
					command_history = { mappings = { [{ "i", "n" }] = { ["<c-d>"] = delete_history_command } } },
					marks = { mappings = { [{ "n" }] = { ["d"] = clear_mark } } },
				},
			})

			require("telescope").load_extension("fzf")

			vim.api.nvim_create_autocmd("User", { pattern = "TelescopePreviewerLoaded", command = "setlocal number" })

			set_hls({
				TelescopeTitle = { link = "Title" },
				TelescopeBorder = { link = "FloatBorder" },
			})
		end,
	},
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		event = "VeryLazy",
		build = "make",
		cond = function()
			return vim.fn.executable("make") == 1
		end,
	},
	{
		"edolphin-ydf/goimpl.nvim",
		ft = "go",
		config = function()
			require("telescope").load_extension("goimpl")

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("User-lspattach-gopls-goimpl", { clear = true }),
				callback = function(args)
					local bufnr = args.buf
					local client_id = args.data.client_id
					local client = vim.lsp.get_client_by_id(client_id)
					if client.name == "gopls" then
						vim.keymap.set("n", "<leader>gi", function()
							require("telescope").extensions.goimpl.goimpl({})
						end, {
							buffer = bufnr,
							desc = "Telescope Goimpl",
							noremap = true,
							silent = true,
						})
						return
					end
				end,
			})
		end,
	},
}
