local ok, _ = pcall(require, "dap")
if not ok then
	return
end

local fn = vim.fn
local api = vim.api
local map = vim.keymap
local cmd = vim.cmd

fn.sign_define("DapBreakpoint", { text = "", texthl = "ErrorMsg", linehl = "", numhl = "ErrorMsg" })
fn.sign_define("DapBreakpointCondition", { text = "", texthl = "ErrorMsg", linehl = "", numhl = "ErrorMsg" })
fn.sign_define("DapBreakpointRejected", { text = "", texthl = "String", linehl = "", numhl = "ErrorMsg" })
fn.sign_define("DapStopped", { text = "", texthl = "String", linehl = "", numhl = "" })

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

dap.set_log_level("ERROR")

local last_config = nil

-- Event {{{2
-- https://microsoft.github.io/debug-adapter-protocol/specification#Events
dap.listeners.before["event_initialized"]["user"] = function(session, body)
	cmd([[doautocmd User DAPInitialized]])

	last_config = session.config
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

-- Cmd {{{
create_cmd("DAPClearBreakpoints", function()
	dap.clear_breakpoints()
end, {})

create_cmd("DapRunLastWithConfig", function()
	if last_config then
		dap.run(last_config)
	else
		dap.continue()
	end
end, {})

create_cmd("DapRunLast", function()
	dap.run_last()
end, {})
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

-- LANG {{{2

-- helper funcs {{{3
local function input_args()
	local argument_string = fn.input("Program arg(s) (enter nothing to leave it null): ")
	return fn.split(argument_string, " ", true)
end
-- }}}

-- Golang {{{3
local dap_func_name_query = "Dap_Test_Func_Name"
vim.treesitter.query.set(
	"go",
	dap_func_name_query,
	[[
(function_declaration
  name: (identifier) @testfuncname
  parameters: (parameter_list
    . (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.(T)")
  (#match? @testfuncname "^Test.+$")) @testfunc

(function_declaration
  name: (identifier) @benchfuncname
  parameters: (parameter_list
    . (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.B")
  (#match? @benchfuncname "^Benchmark.+$")) @benchfunc

(function_declaration
  name: (identifier) @fuzzfuncname
  parameters: (parameter_list
    . (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.F")
  (#match? @fuzzfuncname "^Fuzz.+$")) @fuzzfunc
]]
)
local function get_closest_testfunc()
	local parser = vim.treesitter.get_parser()
	local tree = parser:trees()[1]
	local query = vim.treesitter.query.get("go", dap_func_name_query)

	local closest_node, type
	for _, match, _ in query:iter_matches(tree:root(), 0, 0, api.nvim_win_get_cursor(0)[1]) do
		for id, node in pairs(match) do
			local name = query.captures[id]
			if name == "testfuncname" or name == "benchfuncname" or name == "fuzzfuncname" then
				closest_node = node
				type = name
			end
		end
	end

	return vim.treesitter.get_node_text(closest_node, 0), type
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

-- Rust {{{3
dap.adapters.lldb = {
	name = "lldb",
	type = "executable",
	command = "/usr/bin/lldb-vscode-14",
}
local function init_commands()
	local rustc_sysroot = vim.fn.trim(vim.fn.system("rustc --print sysroot"))

	local script_import = 'command script import "' .. rustc_sysroot .. '/lib/rustlib/etc/lldb_lookup.py"'
	local commands_file = rustc_sysroot .. "/lib/rustlib/etc/lldb_commands"

	local commands = {}
	local file = io.open(commands_file, "r")
	if file then
		for line in file:lines() do
			table.insert(commands, line)
		end
		file:close()
	end
	table.insert(commands, 1, script_import)

	return commands
end
dap.configurations.rust = {
	{
		name = "Nvim: Launch",
		type = "lldb",
		request = "launch",
		program = function()
			local metadata_json = fn.system("cargo metadata --format-version 1 --no-deps")
			local metadata = fn.json_decode(metadata_json)
			if not metadata then
				return fn.input("Path to executable: ", fn.getcwd() .. "/target/debug/", "file")
			end
			local target_dir = metadata.target_directory
			local target_name = metadata.packages[1].targets[1].name
			return target_dir .. "/debug/" .. target_name
		end,
		cwd = "${workspaceFolder}",
		stopOnEntry = false,
		args = function()
			return input_args()
		end,
		runInTerminal = false,
		initCommands = init_commands,
	},
}
dap.configurations.c = dap.configurations.rust
dap.configurations.cpp = dap.configurations.rust
-- }}}

-- Nlua {{{3
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
		collapsed = config.icons.fold[1],
		expanded = config.icons.fold[2],
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

-- map {{{1
map("<Leader>db", dap.toggle_breakpoint, "toggle_breakpoint")
map("<leader>B", function()
	local input = fn.input("[DAP] Condition > ")
	if input then
		dap.set_breakpoint(input)
	end
end)
map("<leader>dn", [[:lua require("dap").step_over()<CR>]], "Step over")
map("<leader>dN", [[:lua require("dap").step_back()<CR>]], "Step back")
map("<leader>di", [[:lua require("dap").step_into()<CR>]], "Step into")
map("<leader>do", [[:lua require("dap").step_out()<CR>]], "Step out")
map("<leader>dc", [[:lua require("dap").continue()<CR>]], "Continue")
map("<leader>dC", [[:lua require("dap").run_to_cursor()<CR>]], "Run to cursor")
map("<leader>dj", [[:lua require("dap").down()<CR>]], "Go down in current stacktrace without stepping")
map("<leader>dk", [[:lua require("dap").up()<CR>]], "Go up in current stacktrace without stepping")
map("<leader>df", [[:lua require("dap").focus_frame()<CR>]], "Jump/focus the current frame")
map("<Leader>dr", function()
	dap.repl.toggle({
		height = 10,
		winfixheight = true,
	})
end, "Toggle dap repl")

map("<leader>dV", function()
	dapui.toggle({ layout = 3, reset = true })
end, "Dap ui scopes")
map("<leader>dB", function()
	dapui.toggle({ layout = 4, reset = true })
end, "Dap ui breakpoints")
map("<leader>dS", function()
	dapui.toggle({ layout = 5, reset = true })
end, "Dap ui stacks")
map("<leader>dW", function()
	dapui.toggle({ layout = 6, reset = true })
end, "Dap ui watches")
-- map("<leader>dc", function()
-- 	dapui.toggle({ layout = 7, reset = true })
-- end, "Dap ui console")
-- map("<leader>dR", function()
-- 	dapui.toggle({ layout = 8, reset = true })
-- end, "Dap ui repl")
-- }}}

-- vim: set foldmethod=marker
