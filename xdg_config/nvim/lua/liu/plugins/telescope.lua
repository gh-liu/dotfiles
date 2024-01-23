local api = vim.api
local keymap = vim.keymap

local builtin = require("telescope.builtin")
local actions = require("telescope.actions")

local borders = config.borders

require("telescope").setup({
	-- Global: Default configuration for telescope
	defaults = {
		-- https://github.com/nvim-telescope/telescope.nvim#default-mappings
		default_mappings = {
			i = {
				["<C-n>"] = actions.move_selection_next,
				["<C-p>"] = actions.move_selection_previous,
				["<Down>"] = actions.move_selection_next,
				["<Up>"] = actions.move_selection_previous,

				["<C-c>"] = actions.close,
				["<esc>"] = actions.close,

				["<CR>"] = actions.select_default,
				["<C-x>"] = actions.select_horizontal,
				["<C-v>"] = actions.select_vertical,
				["<C-t>"] = actions.select_tab,

				["<C-u>"] = actions.preview_scrolling_up,
				["<C-d>"] = actions.preview_scrolling_down,

				["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
				["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
				["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
				["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,

				-- ["<C-l>"] = actions.send_to_loclist + actions.open_loclist,
				["<C-l>"] = actions.complete_tag,

				["<C-/>"] = actions.which_key,
				["<C-_>"] = actions.which_key, -- keys from pressing <C-/>

				["<C-w>"] = { "<c-s-w>", type = "command" },
				["<C-r><C-w>"] = actions.insert_original_cword,

				["<C-j>"] = actions.cycle_history_next,
				["<C-k>"] = actions.cycle_history_prev,
			},
			n = {
				["<esc>"] = actions.close,
				["<C-c>"] = actions.close,

				["<CR>"] = actions.select_default,

				["<C-x>"] = actions.select_horizontal,
				["<C-v>"] = actions.select_vertical,
				["<C-t>"] = actions.select_tab,

				["<Tab>"] = actions.toggle_selection + actions.move_selection_worse,
				["<S-Tab>"] = actions.toggle_selection + actions.move_selection_better,
				["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
				["<M-q>"] = actions.send_selected_to_qflist + actions.open_qflist,

				["j"] = actions.move_selection_next,
				["k"] = actions.move_selection_previous,
				["<Down>"] = actions.move_selection_next,
				["<Up>"] = actions.move_selection_previous,
				["gg"] = actions.move_to_top,
				["G"] = actions.move_to_bottom,

				["<C-k>"] = actions.preview_scrolling_up,
				["<C-j>"] = actions.preview_scrolling_down,
				["<C-h>"] = actions.preview_scrolling_left,
				["<C-l>"] = actions.preview_scrolling_right,

				["?"] = actions.which_key,
			},
		},
		-- stylua: ignore start
		borderchars = { borders[2], borders[4], borders[6], borders[8], borders[1], borders[3], borders[5], borders[7] },
		-- stylua: ignore end
		winblend = 10,
		layout_config = {
			horizontal = { prompt_position = "top", preview_width = 0.6, results_width = 0.8 },
			vertical = { mirror = false },
			width = 0.8,
			height = 0.8,
			preview_cutoff = 120,
		},
		sorting_strategy = "ascending",
		path_display = {
			"truncate",
			-- shorten = { len = 3, exclude = { -1, -2 } },
		},
		file_ignore_patterns = { -- lua regex
			".git/",
			-- "target/", -- rust
			-- "zig%-out/", -- zig
			-- "zig%-cache/", -- zig
		},
	},
	-- Individual: Default configuration for builtin pickers
	pickers = {
		buffers = {
			mappings = { [{ "n" }] = { ["<leader>d"] = actions.delete_buffer } },
		},
		marks = {
			mappings = { [{ "n" }] = { ["<leader>d"] = actions.delete_mark } },
		},
		live_grep = {
			mappings = { [{ "n" }] = { ["<leader>r"] = actions.to_fuzzy_refine } },
		},
		grep_string = {
			mappings = { [{ "n" }] = { ["<leader>r"] = actions.to_fuzzy_refine } },
		},
		find_files = {
			hidden = true,
			no_ignore = false, -- show files ignored by `.gitignore,` `.ignore,` etc.
		},
	},
})

-- keymaps
do
	keymap.set("n", "<leader>so", builtin.oldfiles, { desc = "[S]earch recently [O]pened files" })
	keymap.set("n", "<leader>sb", builtin.buffers, { desc = "[S]earch existing [B]uffers" })
	keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })

	keymap.set({ "n", "x" }, "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
	keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
	keymap.set("n", "<leader>s/", builtin.current_buffer_fuzzy_find, { desc = "[S]earch in Current Buffer like [/]" })
	keymap.set("n", "<leader>ss", builtin.search_history, { desc = "[S]earch [S]earch History" })

	keymap.set("n", "<leader>sm", builtin.marks, { desc = "[S]earch [M]ark" })
	keymap.set("n", "<leader>sj", builtin.jumplist, { desc = "[S]et [J]umplist" })
	keymap.set("n", "<leader>sr", builtin.registers, { desc = "[S]earch [R]egisters" })
	keymap.set("n", "<leader>st", builtin.filetypes, { desc = "[S]et File[t]ype" })
	keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
	keymap.set("n", "<leader>sH", function()
		builtin.help_tags({ default_text = vim.fn.expand("<cword>") })
	end, { desc = "[S]earch [H]elp" })

	-- keymap.set("n", "<leader>;", ":")
	keymap.set("n", "<leader>;", builtin.commands, { desc = "List Commands" })
	-- keymap.set("n", "<leader>:", builtin.command_history, { desc = "List Commands History" })

	keymap.set("n", "<leader>sd", function()
		local count = vim.v.count -- use count as level
		if vim.diagnostic.severity.HINT >= count and count >= vim.diagnostic.severity.ERROR then
			return builtin.diagnostics({ severity = { count } })
		end
		return builtin.diagnostics()
	end, { desc = "[S]earch [D]iagnostics" })

	-- override by builtin.lsp_document_symbols
	keymap.set("n", "<leader>ds", builtin.treesitter, { desc = "Treesitter [D]ocument [S]ymbols" })

	api.nvim_create_autocmd("LspAttach", {
		group = api.nvim_create_augroup("liu/lsp_attach_telescope_keymaps", { clear = true }),
		callback = function(args)
			local map = function(l, r, desc)
				keymap.set("n", l, r, { buffer = args.buf, desc = desc })
			end

			map("<leader>ds", builtin.lsp_document_symbols, "Lists LSP [D]ocument [S]ymbols in the current buffer")

			map("gd", function()
				builtin.lsp_definitions()
			end, "[G]oto [D]efinition")

			map("gy", function()
				builtin.lsp_type_definitions()
			end, "[G]oto T[y]pe Definition")

			map("gr", function()
				builtin.lsp_references({
					include_declaration = false,
					include_current_line = false,
				})
			end, "[G]oto [R]eferences")

			map("gi", function()
				builtin.lsp_implementations({})
			end, "[G]oto [I]mplementation")

			map("gI", builtin.lsp_incoming_calls, "[G]oto [I]ncomingCalls") -- this function as callee
			-- map("gO", builtin.lsp_outgoing_calls, "[G]oto [O]utgoingCalls") -- this function as caller
		end,
	})
end

-- commands
do
	local cmds = {
		GBufferCommits = "git_bcommits",
		GBranches = "git_branches",
		GStash = "git_stash",
	}
	for cmd, fn in pairs(cmds) do
		api.nvim_create_user_command(cmd, function(opts)
			builtin[fn]()
		end, { nargs = 0, desc = "telescope " .. fn })
	end
end

set_hls({ TelescopeBorder = { link = "FloatBorder" } })

api.nvim_create_autocmd("User", {
	pattern = "TelescopePreviewerLoaded",
	command = "setlocal number",
})
