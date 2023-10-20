local api = vim.api
local keymap = vim.keymap

local builtin = require("telescope.builtin")

keymap.set("n", "<leader>so", builtin.oldfiles, { desc = "[S]earch recently [O]pened files" })
keymap.set("n", "<leader>sb", builtin.buffers, { desc = "[S]earch existing [B]uffers" })
keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })

keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })

keymap.set("n", "<leader>sm", builtin.marks, { desc = "[S]earch [M]ark" })
keymap.set("n", "<leader>sj", builtin.jumplist, { desc = "[S]et [J]umplist" })
keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
keymap.set("n", "<leader>sH", function()
	local word = vim.fn.expand("<cword>")
	builtin.help_tags({ default_text = word })
end, { desc = "[S]earch [H]elp" })

keymap.set("n", "<leader>sr", builtin.registers, { desc = "[S]earch [R]egisters" })
keymap.set("n", "<leader>st", builtin.filetypes, { desc = "[S]et File[t]ype" })

keymap.set("n", "<leader>;", builtin.commands, { desc = "List Commands" })
keymap.set("n", "<leader>:", builtin.command_history, { desc = "List Commands History" })

keymap.set("n", "<leader>ds", builtin.treesitter, { desc = "Treesitter [D]ocument [S]ymbols" })

api.nvim_create_autocmd("LspAttach", {
	group = api.nvim_create_augroup("UserLspAttachTelescopeKeymaps", { clear = true }),
	callback = function(args)
		local map = function(l, r, desc)
			keymap.set("n", l, r, { buffer = args.buf, desc = desc })
		end
		map("gd", builtin.lsp_definitions, "[G]oto [D]efinition")
		map("gy", builtin.lsp_type_definitions, "[G]oto T[y]pe Definition")

		map("gr", builtin.lsp_references, "[G]oto [R]eferences")
		map("gi", builtin.lsp_implementations, "[G]oto [I]mplementation")

		map("<leader>ds", builtin.lsp_document_symbols, "Lists LSP [D]ocument [S]ymbols in the current buffer")

		-- map("gI", builtin.lsp_incoming_calls, "[G]oto [I]ncomingCalls")
		-- map("gO", builtin.lsp_outgoing_calls, "[G]oto [O]utgoingCalls")
	end,
})

api.nvim_create_autocmd("DiagnosticChanged", {
	group = api.nvim_create_augroup("UserDiagnosticChangedTelescopeKeymaps", { clear = true }),
	callback = function(args)
		local map = function(l, r, desc)
			keymap.set("n", l, r, { buffer = args.buf, desc = desc })
		end

		map("<leader>sd", function()
			vim.ui.select({ "ALL", "ERROR", "WARN", "INFO", "HINT" }, {
				prompt = "Select Diagnostic",
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
					opts.severity = { choice }
					builtin.diagnostics(opts)
				end
			end)
		end, "[S]earch [D]iagnostics")
	end,
})
