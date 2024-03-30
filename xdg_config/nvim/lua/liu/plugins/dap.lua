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

create_cmd("DapRunLast", function(opts)
	if opts.bang and last_config then
		dap.run(last_config)
	else
		dap.run_last()
	end
end, {
	bang = true,
})

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

create_cmd("DAPClearBreakpoints", function()
	dap.clear_breakpoints()
end, {})

create_cmd("DapStart", function(e)
	-- print(e.fargs[1])
	local config = vim.iter(dap.configurations[vim.bo.ft])
		:filter(function(config)
			return config.name == e.fargs[1]
		end)
		:totable()
	if #config == 1 then
		dap.run(config[1])
	end
end, {
	nargs = 1,
	complete = function(...)
		local configs = dap.configurations[vim.bo.ft]
		return vim.iter(configs)
			:map(function(config)
				return config.name
			end)
			:totable()
	end,
})

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

autocmd("FileType", {
	pattern = "dap-repl",
	group = augroup("liu/dap_exit_repl", { clear = true }),
	callback = function(ev)
		autocmd({ "BufEnter" }, {
			callback = function(ev)
				if fn.winnr("$") < 2 then
					vim.cmd.quit({ bang = true, mods = { silent = true } })
				end
			end,
			buffer = ev.buf,
			nested = true,
		})
	end,
})

-- }}}

-- LANG {{{2

-- helper funcs {{{3

-- https://github.com/mfussenegger/nvim-dap/blob/bbe2c6f3438542a37cc2141a8e385f7dfe07d87d/doc/dap.txt#L263C31
local function get_arguments()
	return coroutine.create(function(dap_run_co)
		local args = {}
		vim.ui.input({
			prompt = "Program argument(s):",
		}, function(input)
			args = vim.split(input or "", " ")
			coroutine.resume(dap_run_co, args)
		end)
	end)
end

-- local function input_args()
-- 	local argument_string = fn.input("Program arg(s) (enter nothing to leave it null): ")
-- 	return fn.split(argument_string, " ", true)
-- end

local function filtered_pick_process()
	return require("dap.utils").pick_process({})
end
-- }}}

-- Golang {{{3
-- test function name {{{
local function get_closest_testfunc()
	local parser = vim.treesitter.get_parser()
	local tree = parser:trees()[1]
	local query = vim.treesitter.query.get("go", "testfunc")

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

local build_flags = "-tags=debug"
dap.configurations.go = {
	{
		name = "Nvim: Launch file",
		type = "go",
		request = "launch",
		mode = "debug",
		program = "${file}",
		buildFlags = build_flags,
	},
	{
		name = "Nvim: Launch package",
		type = "go",
		request = "launch",
		mode = "debug",
		program = "${fileDirname}",
		buildFlags = build_flags,
	},
	-- {
	-- 	name = "Nvim: Launch package(Args)",
	-- 	type = "go",
	-- 	request = "launch",
	-- 	program = "${fileDirname}",
	-- 	args = get_arguments,
	-- 	buildFlags = build_flags,
	-- },
	{
		name = "Nvim: Attach Local Process",
		type = "go",
		mode = "local",
		request = "attach",
		processId = filtered_pick_process,
		buildFlags = build_flags,
	},
	{
		name = "Nvim: Launch test(go.mod)",
		type = "go",
		request = "launch",
		mode = "test",
		program = "./${relativeFileDirname}",
		buildFlags = build_flags,
	},
	{
		name = "Nvim: Launch test function",
		type = "go",
		request = "launch",
		mode = "test",
		program = "${fileDirname}",
		args = function()
			local func_name, type = get_closest_testfunc()
			local args = {}
			local default_func_name = "^" .. func_name .. "$"
			if type == "benchfuncname" then
				args = {
					"-test.bench",
					fn.input({ prompt = "Function to bench: ", default = default_func_name }),
					"-test.run",
					"a^",
				}
			elseif type == "fuzzfuncname" then
				args = {
					"-test.fuzz",
					fn.input({ prompt = "Function to fuzz: ", default = default_func_name }),
					"-test.fuzzcachedir",
					"./testdata",
					"-test.run",
					"a^",
				}
			else
				args = {
					"-test.run",
					fn.input({ prompt = "Function to test: ", default = default_func_name }),
				}
			end
			return args
		end,
		buildFlags = build_flags,
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
			return coroutine.create(function(dap_run_co)
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
				local program = target_dir .. "/debug/" .. target_name

				coroutine.resume(dap_run_co, program)
			end)
		end,
		cwd = "${workspaceFolder}",
		stopOnEntry = false,
		runInTerminal = false,
		-- initCommands = init_commands,
		-- lldb-vscode by default doesn't inherit the environment variables from the parent.
		-- env = function()
		-- 	local variables = {}
		-- 	for k, v in pairs(vim.fn.environ()) do
		-- 		table.insert(variables, string.format("%s=%s", k, v))
		-- 	end
		-- 	return variables
		-- end,
	},
}
-- }}}

-- Zig {{{3
dap.adapters.codelldb = {
	type = "server",
	port = "${port}",
	executable = {
		command = vim.fn.expand("$HOME/tools/codelldb/extension/adapter/codelldb"),
		args = { "--port", "${port}" },
	},
}

dap.configurations.zig = {
	{
		type = "codelldb",
		-- type = "lldb",
		request = "launch",
		name = "Nvim: Launch",
		program = function()
			return coroutine.create(function(dap_run_co)
				local bufname = vim.fn.bufname()
				local bin_name = vim.fn.expand("%:p:r"):gsub("/", "_")
				local program = "zig-out/bin/" .. bin_name
				-- zig build-exe -femit-bin=zig-out/bin/out src/main.zig
				local obj = vim.system({ "zig", "build-exe", "-femit-bin=" .. program, bufname }, { text = true })
					:wait(1000)
				if obj.code == 1 then
					program = fn.input("Path to executable: ", fn.getcwd() .. "/zig-out/bin/", "file")
				end

				coroutine.resume(dap_run_co, program)
			end)
		end,
		cwd = "${workspaceFolder}",
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

dap.adapters.nlua2 = function(callback, config)
	callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
end

dap.configurations.lua = {
	{
		type = "nlua",
		request = "attach",
		name = "Attach to embeded running Neovim instance",
	},
	{
		type = "nlua2",
		request = "attach",
		name = "Attach to running(by DapRunOSV) Neovim instance",
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

		-- :h dapui.elements
		create_cmd("DapUIFloat", function(arg)
			local args = {} ---@type dapui.FloatElementArgs
			if arg.bang then
				args.enter = true
			end
			dapui.float_element(arg.fargs[1], args)
		end, {
			nargs = 1,
			bang = true,
			complete = function()
				return {
					"scopes",
					"breakpoints",
					"stack",
					"watches",
					"console",
					"repl",
					"exception",
				}
			end,
		})
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

		del_cmd("DapUIFloat")
	end,
	once = true,
	group = uigroup,
	desc = "DAP Terminated",
})
-- }}}

-- Custom Elements {{{2
local dapui_exception = {
	buffer = require("dapui.util").create_buffer("DAP Exceptions", { filetype = "dapui_exceptions" }),
}

function dapui_exception.render()
	-- get the diagnostic information and draw upon rendering/entering.
	local session = require("dap").session()
	if session == nil then
		return
	end
	local buf = dapui_exception.buffer()
	local diagnostics = vim.diagnostic.get(nil, { namespace = session.ns }) ---@type vim.Diagnostic[]
	local msg = table.concat(
		vim.tbl_map(function(d)
			return d.message
		end, diagnostics),
		"\n"
	)
	if not msg or msg == "" then
		msg = "(No exception was caught)"
	end
	pcall(function()
		api.nvim_set_option_value("modifiable", true, { buf = buf })
		api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(msg, "\n"))
		api.nvim_set_option_value("modifiable", false, { buf = buf })
	end)
end

---@return dapui.FloatElementArgs
function dapui_exception.float_defaults()
	return { enter = false }
end

xpcall(function()
	dapui.register_element("exception", dapui_exception)
end, function(err)
	if err:match("already exists") then
		return
	end
	vim.notify(debug.traceback(err, 1), vim.log.levels.ERROR, { title = "dapui" })
end)
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
