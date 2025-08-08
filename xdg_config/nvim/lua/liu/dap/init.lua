require("liu.dap.events")

for _, file in ipairs(vim.fn.readdir(vim.fn.stdpath("config") .. "/lua/liu/dap/adapters", [[v:val =~ '\.lua$']])) do
	-- print("liu.dap.adapters." .. file:gsub("%.lua$", ""))
	require("liu.dap.adapters." .. file:gsub("%.lua$", ""))
end

local dap = require("dap")
if vim.g.dap_configurations and type(vim.g.dap_configurations) == "table" then
	for lang, config in pairs(vim.g.dap_configurations) do
		if dap.configurations[lang] and type(dap.configurations[lang]) == "table" then
			for _, c in ipairs(config) do
				table.insert(dap.configurations[lang], c)
			end
		end
	end
end
dap.defaults.fallback.switchbuf = "usetab,uselast"
-- dap.defaults.fallback.focus_terminal = true
-- dap.defaults.fallback.force_external_terminal = true
-- dap.defaults.fallback.external_terminal = {
-- 	command = "tmux",
-- 	args = {
-- 		"split-pane",
-- 		"-c",
-- 		"#{pane_current_path}",
-- 	},
-- }

-- NOTE: sync maps in plugin spec
vim.g.dap_map_prefix = "dc"

local api = vim.api
api.nvim_create_autocmd("User", {
	pattern = "DAPInitialize",
	group = api.nvim_create_augroup("liu/dap_maps-cmds", { clear = true }),
	callback = function(data)
		local map_dap = function(lhs, rhs, desc, mode)
			if desc then
				desc = "[DAP] " .. desc
			end
			lhs = string.format("%s%s", vim.g.dap_map_prefix, lhs)
			vim.keymap.set(mode or "n", lhs, rhs, { silent = true, desc = desc })
		end

		local set_cmds = function(cmds)
			for key, cmd in pairs(cmds) do
				vim.api.nvim_create_user_command(key, cmd, { bang = true, nargs = 0 })
			end
		end

		map_dap(
			"l",
			[[:lua if vim.g.dap_last_config then require("dap").run(vim.g.dap_last_config) print(vim.g.dap_last_config.name) else require("dap").run_last() end<CR>]],
			"run last"
		)
		-- map("c", [[:lua require("dap").continue()<CR>]], "Continue")
		-- map("b", [[:lua require("dap").set_breakpoint()<CR>]], "Toggle Breakpoint")

		map_dap("C", [[:lua require("dap").run_to_cursor()<CR>]], "run to Cursor")

		map_dap("n", [[:lua require("dap").step_over()<CR>]], "Step over")
		map_dap("p", [[:lua require("dap").step_back()<CR>]], "Step back")
		map_dap("i", [[:lua require("dap").step_into()<CR>]], "Step into")
		map_dap("o", [[:lua require("dap").step_out()<CR>]], "Step out")

		map_dap("j", [[:lua require("dap").down()<CR>]], "Go down in current stacktrace without stepping")
		map_dap("k", [[:lua require("dap").up()<CR>]], "Go up in current stacktrace without stepping")
		map_dap("f", [[:lua require("dap").focus_frame()<CR>]], "Jump/focus the current frame")

		map_dap("r", function()
			dap.repl.toggle({ height = 12, winfixheight = true })
		end)
		map_dap("q", [[:lua require("dap").terminate()<CR>]], "Terminates the debug session")

		-- map_dap("L", function()
		-- 	local logpoint = vim.fn.input({ prompt = "Log point message: " })
		-- 	if logpoint and logpoint ~= "" then
		-- 		dap.toggle_breakpoint(nil, nil, logpoint, true)
		-- 	end
		-- end)
		-- map_dap("B", function()
		-- 	local condition = vim.fn.input({ prompt = "Breakpoint Condition: " })
		-- 	if condition and condition ~= "" then
		-- 		dap.toggle_breakpoint(condition, nil, nil, true)
		-- 	end
		-- end)

		local widgets = require("dap.ui.widgets")
		map_dap("K", function()
			widgets.hover()
		end, "hover", { "n", "v" })
		map_dap("P", function()
			widgets.preview(nil, { listener = { "event_stopped" } })
		end, "hover", { "n", "v" })

		local wincmd = "leftabove 30vnew"
		local scopes = widgets.sidebar(widgets.scopes, {}, wincmd)
		local frames = widgets.sidebar(widgets.frames, {}, wincmd)
		local threads = widgets.sidebar(widgets.threads, {}, wincmd)
		set_cmds({
			DapScopes = scopes.toggle,
			DapFrames = frames.toggle,
			DapThreads = threads.toggle,
		})
	end,
	once = true,
})

api.nvim_create_autocmd({ "FileType" }, {
	pattern = "dap-float",
	callback = function(ev)
		local buf = ev.buf
		vim.keymap.set("n", "q", "<cmd>quit<cr>", { buffer = buf })
	end,
})

-- dap-repl {{{3
api.nvim_create_autocmd("FileType", {
	pattern = "dap-repl",
	group = vim.api.nvim_create_augroup("liu/dap/repl-setup", { clear = true }),
	callback = function(ev)
		vim.cmd([[syntax match Debug '^dap>']])

		vim.b.blink_cmp_provider = { "buffer", "omni" }

		local win = vim.api.nvim_get_current_win()
		-- vim.wo[win].winfixbuf = true

		api.nvim_create_autocmd("BufWinEnter", {
			desc = "dap-repl-buffer",
			buffer = ev.buf,
			callback = function()
				local win = vim.api.nvim_get_current_win()
				vim.wo[win][0].signcolumn = "no"
				vim.wo[win][0].foldcolumn = "0"
				vim.wo[win][0].number = false
				vim.wo[win][0].relativenumber = false
			end,
		})

		api.nvim_create_autocmd({ "BufEnter" }, {
			callback = function(ev)
				if vim.fn.winnr("$") < 2 then
					vim.cmd.quit({ bang = true, mods = { silent = true } })
				end
			end,
			buffer = ev.buf,
		})
	end,
})
-- }}}
