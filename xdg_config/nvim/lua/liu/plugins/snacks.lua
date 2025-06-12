---@param highlights table
local set_hls = function(highlights)
	for group, opts in pairs(highlights) do
		vim.api.nvim_set_hl(0, group, opts)
	end
end
local api = vim.api
local fn = vim.fn

vim.cmd([[
	func! SnacksPreviewWinbar() abort
		let linenr = search("\\v^[[:alpha:]$_]", "bn", 1, 100)
		if linenr == 0 
			return ""
		end
		let line = getline(linenr)
		return linenr . ": " . line
	endfunc
]])
return {
	{
		"folke/snacks.nvim",
		event = "VeryLazy",
		opts = {
			styles = {
				zoom_indicator = {
					text = "▍ z  󰊓  ",
					row = vim.o.showtabline > 0 and 1 or 0,
				},
			},
			-- scroll = {},
			bigfile = {},
			words = {
				modes = { "n" },
			},
			---@type snacks.picker.Config
			picker = {
				ui_select = true, -- vim.ui.select
				--- UI
				win = {
					-- input window
					input = {
						keys = {
							["<CR>"] = { "confirm", mode = { "n", "i" } },
							["<S-CR>"] = { { "pick_win", "jump" }, mode = { "n", "i" } },
							["<C-c>"] = { "close", mode = { "n", "i" } },
							["<Esc>"] = { "close", mode = { "n", "i" } },
							["q"] = "close",
							-- ["<Esc>"] = "close",
							--
							["<C-j>"] = { "history_forward", mode = { "i", "n" } },
							["<C-k>"] = { "history_back", mode = { "i", "n" } },
							--
							-- ["<C-j>"] = { "list_down", mode = { "n" } },
							-- ["<C-k>"] = { "list_up", mode = { "n" } },
							["<C-n>"] = { "list_down", mode = { "i", "n" } },
							["<C-p>"] = { "list_up", mode = { "i", "n" } },
							["j"] = "list_down",
							["k"] = "list_up",
							["G"] = "list_bottom",
							["gg"] = "list_top",
							--
							["<c-d>"] = { "preview_scroll_down", mode = { "i", "n" } },
							["<c-u>"] = { "preview_scroll_up", mode = { "i", "n" } },
							--
							["<Tab>"] = { "select_and_next", mode = { "i", "n" } },
							["<S-Tab>"] = { "select_and_prev", mode = { "i", "n" } },
							--
							["<C-w>"] = { "<c-s-w>", mode = { "i" }, expr = true, desc = "delete word" },
							["<C-a>"] = { "<Home>", mode = { "i" }, expr = true },
							["<C-f>"] = { "<right>", mode = { "i" }, expr = true },
							["<C-b>"] = { "<left>", mode = { "i" }, expr = true },
							-- vim-rsi
							["<M-f>"] = { "<S-Right>", mode = { "i" }, expr = true },
							["<M-b>"] = { "<S-Left>", mode = { "i" }, expr = true },
							--
							["<a-w>"] = { "cycle_win", mode = { "i", "n" } },
							--
							["<c-q>"] = { "qflist", mode = { "i", "n" } },
							--
							["<c-s>"] = { "edit_split", mode = { "i", "n" } },
							["<c-v>"] = { "edit_vsplit", mode = { "i", "n" } },
							--
							["g?"] = "toggle_help_input",

							["<c-g>"] = { "toggle_live", mode = { "i", "n" } },
						},
						b = {
							minipairs_disable = true,
						},
						wo = {
							stl = "%f",
						},
					},
					-- result list window
					list = {
						keys = {
							["i"] = "focus_input",
							--
							["<CR>"] = "confirm",
							["<Esc>"] = "close",
							["q"] = "close",
							--
							["<Down>"] = "list_down",
							["<Up>"] = "list_up",
							-- ["<c-j>"] = "list_down",
							-- ["<c-k>"] = "list_up",
							["<c-n>"] = "list_down",
							["<c-p>"] = "list_up",
							["G"] = "list_bottom",
							["gg"] = "list_top",
							--
							["<S-Tab>"] = { "select_and_prev", mode = { "n", "x" } },
							["<Tab>"] = { "select_and_next", mode = { "n", "x" } },
							--
							["<a-w>"] = "cycle_win",
							["<a-d>"] = "inspect",
							--
							["<c-d>"] = "list_scroll_down",
							["<c-u>"] = "list_scroll_up",
							--
							["<c-q>"] = "qflist",
							--
							["<c-s>"] = "edit_split",
							["<c-v>"] = "edit_vsplit",
							--
							["?"] = "toggle_help_list",
						},
						wo = {
							conceallevel = 2,
							concealcursor = "nvc",
							stl = "%f",
						},
					},
					-- preview window
					preview = {
						keys = {
							["i"] = "focus_input",
							--
							["q"] = "close",
							["<Esc>"] = "close",
							--
							["<a-w>"] = "cycle_win",
						},
						wo = {
							-- winbar = "%{SnacksPreviewWinbar()}%<",
							stl = "%f",
						},
					},
				},
				layouts = {
					default = {
						layout = {
							backdrop = false,
						},
					},
				},
			},
		},
		config = function(_, opts)
			-- Toggle {{{
			-- :h *unimpaired-toggling*
			-- https://github.com/tpope/vim-unimpaired/blob/6d44a6dc2ec34607c41ec78acf81657248580bf1/doc/unimpaired.txt#L77
			Snacks.toggle.option("spell", { name = "Spelling" }):map("yos")
			Snacks.toggle.option("wrap", { name = "Wrap" }):map("yow")
			Snacks.toggle.option("diff", { name = "Diff" }):map("yod")
			Snacks.toggle.option("hlsearch", { name = "Hlsearch" }):map("yoh")
			Snacks.toggle.option("list", { name = "List" }):map("yol")
			Snacks.toggle.option("previewwindow", { name = "Previewwindow" }):map("yop")
			Snacks.toggle.option("ignorecase", { name = "Ignorecase" }):map("yoi")

			Snacks.toggle.option("winfixbuf", { name = "winFixbuf" }):map("yof")
			Snacks.toggle.zoom():map("yuz")
			Snacks.toggle.line_number():map("yon")
			Snacks.toggle({
				name = "Quickfix",
				get = function()
					for _, win in pairs(vim.fn.getwininfo()) do
						if win["quickfix"] == 1 then
							return true
						end
					end
					return false
				end,
				set = function(state)
					if state then
						vim.cmd("copen")
					else
						vim.cmd("cclose")
					end
				end,
			}):map("yuq")
			-- }}}

			require("snacks").setup(opts)

			-- words {{{3
			vim.keymap.set({ "n" }, "]w", function()
				Snacks.words.jump(vim.v.count1, true)
			end, {})
			vim.keymap.set({ "n" }, "[w", function()
				Snacks.words.jump(-vim.v.count1, true)
			end, {})
			-- }}}

			-- bufdelete {{{3
			_G.bufdelete = Snacks.bufdelete
			vim.keymap.set({ "n" }, "<leader>bd", function()
				Snacks.bufdelete()
			end, {})
			-- }}}

			-- Picker {{{
			vim.cmd([[nnoremap \f :lua Snacks.picker.()<left><left>]])

			local keys = {
				{ "<leader>sb", "buffers" },
				{ "<leader>sg", "grep" },
				{ "<leader>sf", "files" },
				{
					"<leader>sp",
					"projects",
					opts = {
						layout = "default",
						win = {
							input = {
								keys = {
									["<c-t>"] = { { "open_in_new_tab" }, mode = { "n", "i" } },
								},
							},
						},
						confirm = "load_project_session",
						actions = {
							open_in_new_tab = function(picker, item)
								vim.cmd("tabnew")
								Snacks.notify("New tab opened")
								picker:close()
								vim.cmd.tcd(Snacks.picker.util.dir(item))
							end,
							load_project_session = function(picker, item)
								picker:close()
								if not item then
									return
								end
								local dir = item.file
								local session_loaded = false
								vim.api.nvim_create_autocmd("SessionLoadPost", {
									once = true,
									callback = function()
										session_loaded = true
									end,
								})
								vim.defer_fn(function()
									if not session_loaded then
										Snacks.picker.files()
									end
								end, 100)
								vim.cmd.tcd(dir)
								if
									vim.fn.empty(vim.v.this_session) == 1
									and vim.fn.filereadable(dir .. "/Session.vim") == 1
								then
									vim.cmd("source Session.vim")
								end
							end,
						},
					},
				},
				{ "<leader>s/", "lines", opts = { layout = "default" } },
				{ "<leader>sw", "grep_word", mode = { "n", "x" } },
				{
					"<leader>sr",
					"registers",
					opts = {
						-- transform = function(item)
						-- 	if item.label and item.label:match("^[A-Za-z0-9]$") then
						-- 		return item
						-- 	end
						-- 	return false
						-- end,
						actions = {
							del_reg = function(picker, item, action)
								picker.preview:reset()
								local reg = item.label
								local ok, _ = pcall(vim.cmd, string.format([[let @%s=""]], reg))
								if ok then
									picker.list:set_selected()
									picker.list:set_target()
									picker:find()
								end
							end,
						},
						win = {
							input = {
								keys = {
									["<c-x>"] = { "del_reg", mode = { "n", "i" } },
								},
							},
						},
					},
				},
				{
					"<leader>;",
					"commands",
					opts = {
						layout = "select",
						actions = {
							exec_cmd = function(picker, item)
								picker:close()
								if item and item.command and item.command.nargs == "0" then
									vim.schedule(function()
										vim.cmd(item.cmd)
										vim.fn.histadd("cmd", item.cmd)
									end)
									return
								end
								require("snacks.picker.actions").cmd(picker, item)
							end,
						},
						confirm = "exec_cmd",
					},
				},
				{ "<leader>sd", "diagnostics" },
				{ "<leader>sD", "diagnostics_buffer" },
				{ "<leader>sh", "help" },
				{ "<leader>sj", "jumps" },
				{
					"<leader>sm",
					"marks",
					opts = {
						transform = function(item)
							if item.label and item.label:match("^[A-Za-z]$") then
								return item
							end
							return false
						end,
						actions = {
							del_mark = function(picker, item, action)
								picker.preview:reset()
								local success
								local mark = item.label
								if mark:match("%u") then
									success = pcall(vim.api.nvim_del_mark, mark)
								else
									local bufnr = vim.fn.bufnr(item.file)
									success = pcall(vim.api.nvim_buf_del_mark, bufnr, mark)
								end
								if success then
									picker.list:set_selected()
									picker.list:set_target()
									picker:find()
								end
							end,
						},
						win = {
							input = {
								keys = {
									["<c-x>"] = { "del_mark", mode = { "n", "i" } },
								},
							},
						},
					},
				},
				{ "<leader>sl", "loclist" },
				{ "<leader>sq", "qflist" },
				{ "<leader>st", "treesitter" },
				{ "<leader>ss", "lsp_symbols" },
				{ "<leader>sS", "lsp_workspace_symbols" },
				{ "gd", "lsp_definitions" },
				{ "gD", "lsp_declarations" },
				{ "gr", "lsp_references" },
				{ "gI", "lsp_implementations" },
				{ "gy", "lsp_type_definitions" },
			}
			for _, key in ipairs(keys) do
				vim.keymap.set(key["mode"] or { "n" }, key[1], function()
					local opts = key["opts"] or {}
					Snacks.picker[key[2]](opts)
				end)
			end
			vim.keymap.set("n", "<leader>sc", function()
				Snacks.picker({
					title = "Compilers",
					finder = function()
						local compilers = vim.fn.getcompletion("", "compiler")
						local items = {} ---@type snacks.picker.finder.Item[]
						for idx, c in ipairs(compilers) do
							if not vim.startswith(c, "__") then
								table.insert(items, {
									idx = idx,
									score = idx,
									text = c,
								})
							end
						end
						return items
					end,
					format = "text",
					confirm = function(picker, item)
						picker:close()
						vim.schedule(function()
							local cmd = "compiler " .. item.text
							vim.cmd(cmd)
							vim.fn.histadd("cmd", cmd)
						end)
					end,
					layout = "select",
				})
			end)

			set_hls({
				SnacksPickerDir = { link = "Directory" },
				SnacksPickerBufFlags = { link = "@attribute" },
				SnacksPickerCol = { link = "@attribute.builtin" },
			})
			-- }}}
		end,
	},
}
