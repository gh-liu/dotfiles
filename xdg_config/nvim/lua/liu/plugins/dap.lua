local ok, _ = pcall(require, "dap")
if not ok then
	return
end

local fn = vim.fn
local api = vim.api
local map = vim.keymap
local cmd = vim.cmd

fn.sign_define("DapBreakpoint", { text = "●", texthl = "ErrorMsg", linehl = "", numhl = "ErrorMsg" })
fn.sign_define("DapBreakpointCondition", { text = "○", texthl = "ErrorMsg", linehl = "", numhl = "ErrorMsg" })
fn.sign_define("DapStopped", { text = "→", texthl = "String", linehl = "", numhl = "" })

local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local create_cmd = api.nvim_create_user_command
local del_cmd = api.nvim_del_user_command

local map = function(lhs, rhs, desc)
	if desc then
		desc = "[DAP] " .. desc
	end
	map.set("n", lhs, rhs, { silent = true, desc = desc })
end

-- DAP {{{1
local dap = require("dap")

local replwinopts = {
	height = 10,
	winfixheight = true,
}

map("<Leader>dr", function()
	dap.repl.toggle(replwinopts)
end, "toggle dap repl")

map("<Leader>db", dap.toggle_breakpoint, "toggle_breakpoint")
map("<leader>B", function()
	local input = fn.input("[DAP] Condition > ")
	if input then
		dap.set_breakpoint(input)
	end
end)

-- Event {{{2
-- https://microsoft.github.io/debug-adapter-protocol/specification#Events
dap.listeners.before["event_initialized"]["user"] = function(session, body)
	cmd([[doautocmd User DAPInitialized]])
end

dap.listeners.after["event_stopped"]["user"] = function(session, body)
	cmd([[doautocmd User DAPStopped]])
end

dap.listeners.after["event_exited"]["user"] = function(session, body)
	cmd([[doautocmd User DAPExited]])
end

dap.listeners.after["event_terminated"]["user"] = function(session, body)
	cmd([[doautocmd User DAPTerminated]])
end

local group = augroup("UserDAPSettings", { clear = true })
autocmd("User", {
	pattern = "DAPInitialized",
	callback = function()
		vim.g.debuging = 1

		create_cmd("DapRunLast", function()
			dap.run_last()
		end, {})
	end,
	group = group,
	desc = "DAP Initialized",
})

autocmd("User", {
	pattern = { "DAPTerminated" },
	callback = function()
		vim.g.debuging = nil
	end,
	group = group,
	desc = "DAP Terminated",
})
-- }}}

-- helper funcs {{{2
local function input_args()
	local argument_string = fn.input("Program arg(s) (enter nothing to leave it null): ")
	return fn.split(argument_string, " ", true)
end
-- }}}

-- Golang {{{2
local function get_closest_testfunc()
	local parser = vim.treesitter.get_parser(0)
	local root = (parser:parse()[1]):root()

	local query = vim.treesitter.query.get("go", "test")

	local closet_node, type
	for pattern, match, metadata in query:iter_matches(root, 0, 0, api.nvim_win_get_cursor(0)[1]) do
		for id, node in pairs(match) do
			local name = query.captures[id]
			if name == "testfuncname" or name == "benchfuncname" or name == "fuzzfuncname" then
				closet_node = node
				type = name
			end
		end
	end

	return vim.treesitter.get_node_text(closet_node, 0), type
end

dap.adapters.delve = {
	type = "server",
	port = "${port}",
	executable = {
		command = "dlv",
		args = { "dap", "-l", "127.0.0.1:${port}" },
	},
}
dap.adapters.go = dap.adapters.delve
dap.configurations.go = {
	{
		name = "Nvim: Launch file",
		type = "delve",
		request = "launch",
		mode = "debug",
		program = "${file}",
		buildFlags = "-tags=debug",
	},
	{
		name = "Nvim: Launch file with args",
		type = "delve",
		request = "launch",
		mode = "debug",
		program = "${file}",
		args = function()
			return input_args()
		end,
		buildFlags = "-tags=debug",
	},
	{
		name = "Nvim: Launch package",
		type = "delve",
		request = "launch",
		mode = "debug",
		program = "${fileDirname}",
		buildFlags = "-tags=debug",
	},
	{
		name = "Nvim: Launch package with args",
		type = "delve",
		request = "launch",
		mode = "debug",
		program = "${fileDirname}",
		args = function()
			return input_args()
		end,
		buildFlags = "-tags=debug",
	},
	{
		name = "Nvim: Launch test(go.mod)",
		type = "delve",
		request = "launch",
		mode = "test",
		program = "./${relativeFileDirname}",
	},
	{
		name = "Nvim: Launch test function",
		type = "delve",
		request = "launch",
		mode = "test",
		program = "${file}",
		args = function()
			local func_name, type = get_closest_testfunc()
			local args = {}
			if type == "benchfuncname" then
				args = {
					"-test.run=none",
					"-test.bench",
					fn.input({ prompt = "Function to bench: ", default = func_name }),
				}
			elseif type == "fuzzfuncname" then
				args = {
					"-test.run=none",
					"-test.fuzz",
					fn.input({ prompt = "Function to fuzz: ", default = func_name }),
					"-test.fuzzcachedir",
					"./testdata",
				}
			else
				args = {
					"-test.run",
					fn.input({ prompt = "Function to test: ", default = func_name }),
				}
			end
			return table.insert(args, "-v")
		end,
	},
}
-- }}}

-- Rust {{{2
dap.adapters.lldb = {
	name = "lldb",
	type = "executable",
	command = "/usr/bin/lldb-vscode-14",
}
dap.configurations.rust = {
	{
		name = "Nvim: Launch",
		type = "lldb",
		request = "launch",
		program = function()
			local metadata_json = fn.system("cargo metadata --format-version 1 --no-deps")
			local metadata = fn.json_decode(metadata_json)
			if not metadata then
				return fn.input("Path to executable: ", fn.getcwd() .. "/", "file")
			end
			local target_name = metadata.packages[1].targets[1].name
			local target_dir = metadata.target_directory
			return target_dir .. "/debug/" .. target_name
		end,
		cwd = "${workspaceFolder}",
		stopOnEntry = false,
		args = function()
			return input_args()
		end,
		runInTerminal = false,
	},
}
dap.configurations.c = dap.configurations.rust
dap.configurations.cpp = dap.configurations.rust
-- }}}

-- Nlua {{{
local nvim_instance
dap.adapters.nlua = function(cb, config)
	if nvim_instance then
		fn.jobstop(nvim_instance)
		nvim_instance = nil
	end

	local args = { vim.v.progpath, "--embed", "--headless" }
	local env = nil
	nvim_instance = fn.jobstart(args, { rpc = true, env = env })
	assert(nvim_instance, "Could not create neovim instance with jobstart!")

	local mode = fn.rpcrequest(nvim_instance, "nvim_get_mode")
	assert(not mode.blocking, "Neovim is waiting for input at startup. Aborting.")

	local opts = {}
	local server = fn.rpcrequest(nvim_instance, "nvim_exec_lua", [[return require"osv".launch(...)]], { opts })
	vim.wait(200)
	assert(server, "Could not launch osv server!")

	local host = server.host
	local port = server.port

	cb({ type = "server", host = host or "127.0.0.1", port = port or 8086 })

	dap.listeners.after["setBreakpoints"]["osv"] = function(session, body)
		vim.schedule(function()
			fn.rpcnotify(nvim_instance, "nvim_command", "luafile " .. fn.expand("%:p"))
		end)
	end
end

dap.configurations.lua = {
	{
		type = "nlua",
		request = "attach",
		name = "Attach to running Neovim instance",
	},
}
-- }}}

-- Repl {{{2
local repl = require("dap.repl")
repl.commands = vim.tbl_extend("force", repl.commands, {
	exit = { ".q" },
	custom_commands = {
		[".restart"] = dap.run_last,
	},
})
-- }}}

require("dap.ext.vscode").load_launchjs()
-- }}}

-- DAPUI {{{1
local dapui = require("dapui")

local left_element_width = 35

-- Settings {{{2
dapui.setup({
	controls = { enabled = false },
	expand_lines = false,
	force_buffers = true,
	floating = {
		border = config.borders,
		mappings = { close = { "q", "<Esc>" } },
	},
	icons = {
		collapsed = config.fold_markers[1],
		expanded = config.fold_markers[2],
		current_frame = "⇒",
	},
	layouts = {
		{
			elements = {
				{
					id = "watches",
					size = 0.25,
				},
				{
					id = "breakpoints",
					size = 0.25,
				},
				{
					id = "stacks",
					size = 0.25,
				},
				{
					id = "scopes",
					size = 0.25,
				},
			},
			position = "left",
			size = left_element_width,
		},
		{
			elements = {
				{
					id = "console",
					size = 0.5,
				},
				{
					id = "repl",
					size = 0.5,
				},
			},
			position = "bottom",
			size = 10,
		},
		-- {layout = 3}
		{
			elements = {
				{
					id = "scopes",
					size = 1,
				},
			},
			position = "left",
			size = left_element_width,
		},
		-- {layout = 4}
		{
			elements = {
				{
					id = "breakpoints",
					size = 1,
				},
			},
			position = "left",
			size = left_element_width,
		},
		-- {layout = 5}
		{
			elements = {
				{
					id = "stacks",
					size = 1,
				},
			},
			position = "left",
			size = left_element_width,
		},
		-- {layout = 6}
		{
			elements = {
				{
					id = "watches",
					size = 1,
				},
			},
			position = "left",
			size = left_element_width,
		},

		-- {layout = 7}
		{
			elements = {
				{
					id = "console",
					size = 1,
				},
			},
			position = "bottom",
			size = 10,
		},
		-- {layout = 8}
		{
			elements = {
				{
					id = "repl",
					size = 1,
				},
			},
			position = "bottom",
			size = 10,
		},
	},
	mappings = {
		expand = { "<TAB>" },
		open = "<CR>",
		remove = "d",
		edit = "e",
		repl = "r",
		toggle = "t",
	},
	element_mappings = {},
	render = {
		indent = 1,
		max_value_lines = 100,
	},
})

local colors = config.colors
local groups = {
	DapUIType = { fg = colors.magenta },
	DapUIScope = { fg = colors.cyan },
	DapUIModifiedValue = { fg = colors.cyan, bold = true },
	DapUIDecoration = { fg = colors.cyan },
	DapUIThread = { fg = colors.green },
	DapUIStoppedThread = { fg = colors.cyan },
	DapUISource = { fg = colors.magenta },
	DapUILineNumber = { fg = colors.cyan },
	DapUIFloatBorder = { fg = colors.cyan },
	DapUIWatchesEmpty = { fg = colors.red },
	DapUIWatchesValue = { fg = colors.green },
	DapUIWatchesError = { fg = colors.red },
	DapUIBreakpointsPath = { fg = colors.cyan },
	DapUIBreakpointsInfo = { fg = colors.green },
	DapUIBreakpointsCurrentLine = { fg = colors.cyan, bold = true },
	DapUIBreakpointsDisabledLine = { fg = colors.gray },
	DapUIStepOver = { fg = colors.cyan },
	DapUIStepInto = { fg = colors.cyan },
	DapUIStepBack = { fg = colors.cyan },
	DapUIStepOut = { fg = colors.cyan },
	DapUIStop = { fg = colors.red },
	DapUIPlayPause = { fg = colors.green },
	DapUIRestart = { fg = colors.green },
	DapUIUnavailable = { fg = colors.gray },
	DapUIWinSelect = { fg = colors.cyan, bold = true },
}
set_hls(groups)

-- Event {{{2
local uigroup = augroup("UserDAPUISettings", { clear = true })
autocmd("User", {
	pattern = "DAPInitialized",
	callback = function()
		local opts = { enter = true }
		map("<Leader>de", function()
			dapui.eval(nil, opts)
		end)
		map("<Leader>E", function()
			local input = fn.input("[DAP] Expression > ")
			if input then
				dapui.eval(input, opts)
			end
		end)

		-- create_cmd("DapUI", function()
		-- 	dapui.toggle({ layout = 1, reset = true })
		-- end, {})

		create_cmd("DapUIScopes", function()
			-- dapui.float_element("scopes", opts)
			dapui.toggle({ layout = 3, reset = true })
		end, {})
		create_cmd("DapUIBreakpoints", function()
			-- dapui.float_element("breakpoints", opts)
			dapui.toggle({ layout = 4, reset = true })
		end, {})
		create_cmd("DapUIStacks", function()
			-- dapui.float_element("stacks", opts)
			dapui.toggle({ layout = 5, reset = true })
		end, {})
		create_cmd("DapUIWatches", function()
			-- dapui.float_element("watches", opts)
			dapui.toggle({ layout = 6, reset = true })
		end, {})

		create_cmd("DapUIConsole", function()
			-- dapui.float_element("console", opts)
			dapui.toggle({ layout = 7, reset = true })
		end, {})
		create_cmd("DapUIRepl", function()
			-- dapui.float_element("repl", opts)
			dapui.toggle({ layout = 8, reset = true })
		end, {})
	end,
	group = uigroup,
	desc = "DAP Initialized",
})

autocmd("User", {
	pattern = { "DAPTerminated" },
	callback = function()
		dapui.close()

		-- del_cmd("DapUI")
		del_cmd("DapUIBreakpoints")
		del_cmd("DapUIWatches")
		del_cmd("DapUIStacks")
		del_cmd("DapUIScopes")
	end,
	once = true,
	group = uigroup,
	desc = "DAP Terminated",
})
-- }}}

-- }}}

-- Hydra {{{1
local ok, Hydra = pcall(require, "hydra")
if ok then
	local hint = [[
    ^ ^Step^ ^ ^       ^ ^    Action
 ---^-^----^-^-^----  -^-^------------------
    ^ ^_<C-p>_: back   ^ ^_b_: toggle breakpoint
    ^ ^_<C-n>_: over   ^ ^_B_: clear breakpoints
    ^ ^_do_: step out  ^ ^_C_: continue
    ^ ^_di_: step into ^ ^_X_: terminate
                   ^ ^_r_: run last
    ^ ^UI
 ---^-^---------------^-^-------------------
    ^ ^_dv_: vars     ^ ^_dr_: repl
    ^ ^_dw_: watches  ^ ^_dc_: console
    ^ ^_db_: breakpoints
    ^ ^_ds_: stacktraces

		   ^ ^_<Esc>_/_q_: exit
]]
	-- local Hydra = require("hydra")
	local dap = require("dap")
	local dapui = require("dapui")

	local dap_hydra = Hydra({
		hint = hint,
		config = {
			color = "pink",
			invoke_on_body = true,
			hint = {
				position = "middle-right",
				border = config.borders,
			},
		},
		name = "dap",
		mode = { "n", "x" },
		body = "<C-s>",
		heads = {
			{ "C", dap.continue, { desc = "continue", silent = true } },
			{ "X", dap.terminate, { desc = "terminate", silent = true } },
			{ "r", dap.run_last, { desc = "run last", silent = true } },
			{ "<C-n>", dap.step_over, { desc = "step_over", silent = true } },
			{ "<C-p>", dap.step_back, { desc = "step back", silent = true } },
			{ "di", dap.step_into, { desc = "step_into", silent = true } },
			{ "do", dap.step_out, { desc = "step_out", silent = true } },
			{ "b", dap.toggle_breakpoint, { desc = "breakpoint", silent = true } },
			{ "B", dap.clear_breakpoints, { desc = "clear breakpoints", silent = true } },

			{
				"dv",
				function()
					dapui.toggle({ layout = 3, reset = true })
				end,
				{ desc = "vars ui", silent = true },
			},
			{
				"db",
				function()
					dapui.toggle({ layout = 4, reset = true })
				end,
				{ desc = "breakpoints ui", silent = true },
			},
			{
				"ds",
				function()
					dapui.toggle({ layout = 5, reset = true })
				end,
				{ desc = "stacktraces ui", silent = true },
			},
			{
				"dw",
				function()
					dapui.toggle({ layout = 6, reset = true })
				end,
				{ desc = "watchs ui", silent = true },
			},
			{
				"dc",
				function()
					dapui.toggle({ layout = 7, reset = true })
				end,
				{ desc = "console ui", silent = true },
			},
			{
				"dr",
				function()
					dapui.toggle({ layout = 8, reset = true })
				end,
				{ desc = "repl ui", silent = true },
			},

			{ "q", nil, { exit = true, nowait = true } },
			{ "<Esc>", nil, { exit = true, nowait = true } },
		},
	})
end
-- }}}

-- Hover {{{
local ok, hover = pcall(require, "hover")
if ok then
	hover.register({
		name = "DAP",
		enabled = function()
			return vim.g.debuging == 1
		end,
		execute = function(done)
			dapui.eval(nil, {})
		end,
		priority = 1001,
	})
end
-- }}}

-- vim: set foldmethod=marker foldlevel=1:
