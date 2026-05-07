require("liu.dap.events")

local adapters_dir = vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "liu", "dap", "adapters")
for name, type in vim.fs.dir(adapters_dir) do
	if type == "file" and name:sub(-4) == ".lua" then
		require("liu.dap.adapters." .. name:sub(1, -5))
	end
end

local dap = require("dap")
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

-- :h dap-providers-configs
dap.providers.configs["g:dap_configurations"] = function(bufnr)
	local g = vim.g.dap_configurations
	if type(g) ~= "table" then
		return {}
	end
	return g[vim.bo[bufnr].filetype] or {}
end

vim.api.nvim_set_hl(0, "DebugLine", { link = "CursorLine", default = true })
local signs = {
	DapStopped = { text = "", texthl = "ModeMsg", numhl = "ModeMsg", linehl = "ModeMsg" },
	DapLogPoint = { text = "", texthl = "Tag", numhl = "Tag", linehl = "Tag" },
	DapBreakpoint = { text = "", texthl = "Debug", numhl = "Debug", linehl = "DebugLine" },
	DapBreakpointCondition = { text = "", texthl = "Conditional", numhl = "Conditional", linehl = "Conditional" },
	DapBreakpointRejected = { text = "", texthl = "ErrorMsg", numhl = "ErrorMsg", linehl = "" },
}
for name, opt in pairs(signs) do
	vim.fn.sign_define(name, opt)
end

-- NOTE: sync maps in plugin spec
vim.g.dap_map_prefix = "dc"

local api = vim.api
vim.api.nvim_create_autocmd("User", {
	pattern = "DAPInitialize",
	group = vim.api.nvim_create_augroup("liu/dap_maps-cmds", { clear = true }),
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

		map_dap(
			"?",
			[[:lua vim.api.nvim_echo({ { require("dap").status(), "Debug" } }, false, {})<CR>]],
			"debug status"
		)

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

vim.api.nvim_create_autocmd({ "FileType" }, {
	pattern = "dap-float",
	callback = function(ev)
		local buf = ev.buf
		vim.keymap.set("n", "q", "<cmd>quit<cr>", { buffer = buf })
	end,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
	pattern = "dap-*",
	callback = function(ev)
		local win = vim.api.nvim_get_current_win()
		vim.wo[win][0].signcolumn = "no"
		vim.wo[win][0].foldcolumn = "0"
		vim.wo[win][0].number = false
		vim.wo[win][0].relativenumber = false
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	pattern = "dap-repl",
	group = vim.api.nvim_create_augroup("liu/dap/repl-setup", { clear = true }),
	callback = function(ev)
		vim.cmd([[syntax match Debug '^dap>']])

		vim.b.blink_cmp_sources = { "buffer", "omni" }

		local win = vim.api.nvim_get_current_win()
		-- vim.wo[win].winfixbuf = true

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
