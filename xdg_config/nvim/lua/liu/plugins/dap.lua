local ok, _ = pcall(require, "dap")
if not ok then
	return
end

-- Base {{{1
local fn = vim.fn
local api = vim.api
local map = vim.keymap
local cmd = vim.cmd
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup
local del_cmd = api.nvim_del_user_command
local create_cmd = api.nvim_create_user_command

local map = function(lhs, rhs, desc)
	if desc then
		desc = "[DAP] " .. desc
	end
	map.set("n", lhs, rhs, { silent = true, desc = desc })
end
-- }}}

-- DAP {{{1
local dap = require("dap")
dap.set_log_level("ERROR")

-- Signs {{{2
fn.sign_define("DapBreakpoint", { text = "", texthl = "Debug", numhl = "Debug", linehl = "" })
fn.sign_define("DapLogPoint", { text = "", texthl = "Tag", numhl = "Tag", linehl = "" })
fn.sign_define("DapBreakpointCondition", { text = "", texthl = "Conditional", numhl = "Conditional", linehl = "" })
fn.sign_define("DapBreakpointRejected", { text = "", texthl = "ErrorMsg", numhl = "ErrorMsg", linehl = "" })
fn.sign_define("DapStopped", { text = "", texthl = "MoreMsg", numhl = "MoreMsg", linehl = "" })
-- }}}

-- Event {{{2
-- https://microsoft.github.io/debug-adapter-protocol/specification#Events
dap.listeners.before["event_initialized"]["user"] = function(session, body)
	-- cmd([[doautocmd User DAPInitialized]])
	local pattern = "DAPInitialized"
	api.nvim_exec_autocmds("User", { pattern = pattern, data = { session = { last_config = session.config } } })
end

dap.listeners.after["event_stopped"]["user"] = function(session, body)
	-- cmd([[doautocmd User DAPStopped]])
	local pattern = "DAPStopped"
	api.nvim_exec_autocmds("User", { pattern = pattern })
end

dap.listeners.after["event_exited"]["user"] = function(session, body)
	-- cmd([[doautocmd User DAPExited]])
	local pattern = "DAPExited"
	api.nvim_exec_autocmds("User", { pattern = pattern })
end

dap.listeners.after["event_terminated"]["user"] = function(session, body)
	-- cmd([[doautocmd User DAPTerminated]])
	local pattern = "DAPTerminated"
	api.nvim_exec_autocmds("User", { pattern = pattern })
end

local group = augroup("liu_dap_settings", { clear = true })
autocmd("User", {
	group = group,
	pattern = { "DAPInitialized" },
	callback = function(ev)
		vim.g.debuging = 1
	end,
	desc = "DAP Initialized",
})

autocmd("User", {
	group = group,
	pattern = { "DAPTerminated" },
	callback = function()
		vim.g.debuging = nil
	end,
	desc = "DAP Terminated",
})
-- }}}

-- Cmd {{{2
local last_config = nil

autocmd("User", {
	group = group,
	pattern = { "DAPInitialized" },
	callback = function(ev)
		last_config = ev.data.session.last_config
		-- vim.print(last_config)
	end,
	desc = "DAP Initialized",
})

create_cmd("DapRunLastWithConfig", function()
	if last_config then
		dap.run(last_config)
	else
		dap.continue()
	end
end, {})

-- DapRunWithArgs {{{3
create_cmd("DapRunWithArgs", function(t)
	local filetype = vim.bo.filetype
	local configurations = dap.configurations[filetype] or {}
	-- check config {{{4
	assert(
		vim.tbl_islist(configurations),
		string.format(
			"`dap.configurations.%s` must be a list of configurations, got %s",
			filetype,
			vim.inspect(configurations)
		)
	)
	if #configurations == 0 then
		local msg =
			"No configuration found for `%s`. You need to add configs to `dap.configurations.%s` (See `:h dap-configuration`)"
		vim.notify(string.format(msg, filetype, filetype), vim.log.levels.INFO)
		return
	end
	-- }}}
	local args = t.fargs
	local approval = vim.fn.confirm(
		"Will try to run:\n    ["
			.. vim.bo.filetype
			.. " bin] "
			.. vim.fn.expand("%")
			.. " "
			.. t.args
			.. "\n\n"
			.. "Do you approve? ",
		"&Yes\n&No",
		1
	)
	if approval == 1 then
		local names = vim.iter(configurations)
			:map(function(item)
				return item.name
			end)
			:totable()

		vim.ui.select(names, {
			prompt = string.format("Select Config of [%s]", filetype),
		}, function(choice, idx)
			if not choice then
				return
			end

			local config = vim.deepcopy(configurations[idx])
			---@diagnostic disable-next-line: inject-field
			config.args = args
			-- vim.print(config)
			dap.run(config)
		end)
	end
end, {
	nargs = "*",
})
-- }}}

create_cmd("DapRunLast", function()
	dap.run_last()
end, {})

create_cmd("DAPClearBreakpoints", function()
	dap.clear_breakpoints()
end, {})
-- }}}

-- Repl {{{2
local repl = require("dap.repl")
repl.commands = vim.tbl_extend("force", repl.commands, {
	exit = { ".q" },
	custom_commands = {
		[".echo"] = function(text)
			dap.repl.append(text)
		end,
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
local dap_go_func_name_query = "Dap_Go_Test_Func_Name"
-- test function name {{{
vim.treesitter.query.set(
	"go",
	dap_go_func_name_query,
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
	local query = vim.treesitter.query.get("go", dap_go_func_name_query)

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
-- }}}

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
		type = "go",
		request = "launch",
		mode = "debug",
		program = "${file}",
		buildFlags = "-tags=debug",
	},
	{
		name = "Nvim: Launch package",
		type = "go",
		request = "launch",
		mode = "debug",
		program = "${fileDirname}",
		buildFlags = "-tags=debug",
	},
	{
		name = "Nvim: Launch test(go.mod)",
		type = "go",
		request = "launch",
		mode = "test",
		program = "./${relativeFileDirname}",
	},
	{
		name = "Nvim: Launch test function",
		type = "go",
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
dap.adapters.rust = dap.adapters.lldb

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
			local obj = vim.system({ "cargo", "build" }, { text = true }):wait(1000)
			if obj.code == 1 then
				-- TODO fail to build
				-- return fn.input("Path to executable: ", fn.getcwd() .. "/target/debug/", "file")
			end

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
		runInTerminal = false,
		initCommands = init_commands,
		-- lldb-vscode by default doesn't inherit the environment variables from the parent.
		env = function()
			local variables = {}
			for k, v in pairs(vim.fn.environ()) do
				table.insert(variables, string.format("%s=%s", k, v))
			end
			return variables
		end,
	},
}
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
	---@diagnostic disable-next-line: missing-fields
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
-- }}}

-- Event {{{2
local uigroup = augroup("UserDAPUISettings", { clear = true })
autocmd("User", {
	pattern = "DAPInitialized",
	callback = function()
		local opts = { enter = true }
		vim.keymap.set({ "n", "v" }, "<Leader>de", function()
			if vim.v.count == 0 then
				dapui.eval(nil, opts)
				return
			end

			local ok, input = pcall(fn.input, "[DAP] Expression > ")
			if ok and input then
				dapui.eval(input, opts)
			end
		end)

		-- map("<Leader>de", function()
		-- 	dapui.eval(nil, opts)
		-- end)
		-- map("<Leader>E", function()
		-- 	local input = fn.input("[DAP] Expression > ")
		-- 	if input then
		-- 		dapui.eval(input, opts)
		-- 	end
		-- end)

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

-- Maps {{{1
map("<Leader>db", function()
	if vim.v.count == 0 then
		dap.toggle_breakpoint()
	end
	if vim.v.count == 1 then
		local ok, input = pcall(fn.input, "[DAP] Condition > ")
		if ok and input then
			dap.set_breakpoint(input)
		end
	end
	if vim.v.count == 2 then
		local ok, input = pcall(fn.input, "[DAP] Log Point > ")
		if ok and input then
			require("dap").set_breakpoint(nil, nil, input)
		end
	end
end, "toggle_breakpoint")

-- map("<Leader>db", dap.toggle_breakpoint, "toggle_breakpoint")
-- map("<leader>B", function()
-- 	local input = fn.input("[DAP] Condition > ")
-- 	if input then
-- 		dap.set_breakpoint(input)
-- 	end
-- end)

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

-- vim: foldmethod=marker
