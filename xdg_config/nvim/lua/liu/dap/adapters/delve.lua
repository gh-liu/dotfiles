local dap = require("dap")

local utils = require("liu.dap.utils")

dap.adapters.go = {
	type = "server",
	port = "${port}",
	executable = {
		command = "dlv",
		args = { "dap", "-l", "127.0.0.1:${port}" },
		options = {
			max_retries = 20,
			initialize_timeout_sec = 5,
		},
	},
	enrich_config = utils.enrich_config,
}
dap.adapters.delve = dap.adapters.go

local build_flags = "-tags=debug"

---@class liu.dap.go_path_mapping
---@field from string
---@field to string

-- https://github.com/golang/vscode-go/wiki/debugging#configuration
---@class liu.dap.config_delve: liu.dap.configuration
---@field type 'go'|'delve'
---@field mode 'debug'|'test'|'auto'|'local'|'remote'
---@field args string[]|nil
---@field asRoot boolean|nil
---@field backend 'default'|'native'|'lldb'|'rr'|nil
---@field buildFlags string[]|string|nil
---@field console liu.dap.console
---@field host string|nil
---@field port number|nil
---@field processId number|nil
---@field program string|nil
---@field substitutePath liu.dap.go_path_mapping[]|nil
---@field cwd string|nil
---@field env string|nil
---@field stopOnEntry boolean|nil

-- make vim.g.dap_configurations works.
dap.configurations.go = {}

local configurations = {}

---@type liu.dap.config_delve[]
configurations.go = {
	{
		name = "Nvim: Launch file",
		type = "delve",
		request = "launch",
		mode = "debug",
		program = "${file}",
		buildFlags = build_flags,
	},
	{
		name = "Nvim: Launch file with args",
		type = "delve",
		request = "launch",
		mode = "debug",
		program = "${file}",
		args = utils.args_fn,
		buildFlags = build_flags,
	},
	{
		name = "Nvim: Launch main.go",
		type = "delve",
		request = "launch",
		mode = "debug",
		program = function()
			return require("dap.utils").pick_file({ filter = "**/main.go", executables = false })
		end,
		buildFlags = build_flags,
	},
	{
		name = "Nvim: Launch package",
		type = "delve",
		request = "launch",
		mode = "debug",
		program = "${fileDirname}",
		buildFlags = build_flags,
	},
	-- https://github.com/golang/vscode-go/wiki/debugging#remote-debugging
	{
		name = "Nvim: Attach local",
		type = "delve",
		request = "attach",
		mode = "local",
		processId = utils.filtered_pick_process,
	},
	{
		name = "Nvim: Attach remote",
		type = "delve",
		request = "attach",
		mode = "remote",
		host = function()
			return coroutine.create(function(dap_run_co)
				local host = vim.fn.input("Host [127.0.0.1]: ")
				host = host ~= "" and host or "127.0.0.1"
				coroutine.resume(dap_run_co, host)
			end)
		end,
		port = function()
			return coroutine.create(function(dap_run_co)
				local port = tonumber(vim.fn.input("Port [5678]: ")) or 5678
				coroutine.resume(dap_run_co, port)
			end)
		end,
	},
}

---@type liu.dap.config_delve[]
configurations.go_test = {
	{
		name = "Nvim: Launch test(go.mod)",
		type = "delve",
		request = "launch",
		mode = "test",
		program = "./${relativeFileDirname}",
		buildFlags = build_flags,
		args = { "-test.v" },
	},
	{
		name = "Nvim: Launch test function",
		type = "delve",
		request = "launch",
		mode = "test",
		program = "${fileDirname}",
		args = function()
			local fname = vim.api.nvim_buf_get_name(0)
			if not vim.endswith(fname, "_test.go") then
				print("not a test file")
				return
			end

			local node, cap_name =
				utils.closest_node("go", "funcs", { "testfuncname", "benchfuncname", "fuzzfuncname" })
			local func_name, type = vim.treesitter.get_node_text(node, 0), cap_name
			local args = {}
			local default_func_name = "^" .. func_name .. "$"
			if type == "benchfuncname" then
				args = {
					"-test.bench",
					vim.fn.input({ prompt = "Function to bench: ", default = default_func_name }),
					"-test.run",
					"a^",
				}
			elseif type == "fuzzfuncname" then
				args = {
					"-test.fuzz",
					vim.fn.input({ prompt = "Function to fuzz: ", default = default_func_name }),
					"-test.fuzzcachedir",
					"./testdata",
					"-test.run",
					"a^",
				}
			else
				args = {
					"-test.run",
					vim.fn.input({ prompt = "Function to test: ", default = default_func_name }),
				}
			end
			table.insert(args, "-test.v")
			return args
		end,
		buildFlags = build_flags,
	},
}

---@return boolean
local is_test = function(bufnr)
	local fname = vim.api.nvim_buf_get_name(bufnr)
	return vim.endswith(fname, "_test.go")
end
dap.providers.configs["delve"] = function(bufnr)
	if is_test(bufnr) then
		return configurations.go_test
	else
		return configurations.go
	end
end
