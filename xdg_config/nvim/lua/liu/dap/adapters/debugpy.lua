-- @need-install: uv tool install --force debugpy
-- @need-install: uv tool install --force pytest
local dap = require("dap")

local utils = require("liu.dap.utils")
local function get_python()
	local venv = vim.fs.find({ "venv", ".venv" }, {
		path = vim.fn.expand("%:p:h"),
		upward = true,
	})[1]
	if venv and vim.fn.executable(venv .. "/bin/python") == 1 then
		return venv .. "/bin/python"
	end
	return vim.fn.exepath("python")
end

local py_adapter = {
	type = "executable",
	enrich_config = utils.enrich_config,
}

if vim.fs.root(0, { "uv.lock" }) then
	py_adapter["command"] = "uv"
	py_adapter["args"] = { "run", "--with", "debugpy", "python", "-m", "debugpy.adapter" }
else
	py_adapter["command"] = get_python()
	py_adapter["args"] = { "-m", "debugpy.adapter" }
end

dap.adapters.python = py_adapter
dap.adapters.debugpy = dap.adapters.python

---@type liu.dap.console
local console = nil

---@class liu.dap.py_path_mapping
---@field localRoot string
---@field remoteRoot string

-- https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings
---@class liu.dap.config_debugpy: liu.dap.configuration
---@field module 'pytest'|'unittest'|nil
---@field type 'python'|'debugpy'
---@field program string|nil
---@field python string[]|nil
---@field args string[]|nil
---@field console liu.dap.console
---@field cwd string|nil
---@field env table|nil
---@field justMyCode boolean|nil
---@field pathMappings liu.dap.py_path_mapping[]|nil
---@field stopOnEntry boolean|nil

---@type liu.dap.config_debugpy[]
dap.configurations.python = {
	-- see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for supported options
	{
		name = "Nvim: Launch file",
		type = "python",
		request = "launch",
		program = "${file}",
		cwd = "${workspaceFolder}",
		console = console,
		pythonPath = get_python,
	},
	{
		name = "Nvim: Launch file with args",
		type = "python",
		request = "launch",
		program = "${file}",
		cwd = "${workspaceFolder}",
		args = utils.args_fn,
		console = console,
		pythonPath = get_python,
	},
	-- https://github.com/mfussenegger/nvim-dap-python/blob/34282820bb713b9a5fdb120ae8dd85c2b3f49b51/lua/dap-python.lua#L179
	{
		name = "Nvim: Current File(unittest)",
		type = "python",
		request = "launch",
		module = "unittest",
		cwd = "${workspaceFolder}",
		args = function()
			local node, _ = utils.closest_node("python", "class_methods", { "method" })
			local method_name = vim.treesitter.get_node_text(node, 0)
			local class_node = node:parent():parent():parent()
			local class_name_node = class_node:named_child(0)
			local class_name = vim.treesitter.get_node_text(class_name_node, 0)

			-- https://code.visualstudio.com/docs/python/testing#_unittest-configuration-settings
			-- https://docs.python.org/3/library/unittest.html#command-line-options
			return {
				"-v",
				"${fileBasenameNoExtension}." .. vim.fn.input({
					prompt = "Test name: ",
					default = class_name .. "." .. method_name,
				}),
			}
		end,
		console = console,
	},
	-- https://github.com/mfussenegger/nvim-dap-python/blob/34282820bb713b9a5fdb120ae8dd85c2b3f49b51/lua/dap-python.lua#L189
	{
		name = "Nvim: Current File(pytest)",
		type = "python",
		request = "launch",
		module = "pytest",
		cwd = "${workspaceFolder}",
		-- https://code.visualstudio.com/docs/python/testing#_pytest-configuration-settings
		-- https://docs.pytest.org/en/latest/reference/reference.html#command-line-flags
		args = {
			"-s",
			"${file}",
			"-W ignore::DeprecationWarning",
		},
		console = console,
	},
	-- django?
	-- https://github.com/mfussenegger/nvim-dap-python/blob/34282820bb713b9a5fdb120ae8dd85c2b3f49b51/lua/dap-python.lua#L201
	-- doctest?
	-- https://github.com/mfussenegger/nvim-dap-python/blob/34282820bb713b9a5fdb120ae8dd85c2b3f49b51/lua/dap-python.lua#L312C17-L312C24
	{
		name = "Nvim: Attach local",
		type = "python",
		request = "attach",
		pid = utils.filtered_pick_process,
	},
	{
		name = "Nvim: Attach remote",
		type = "python",
		request = "attach",
		connect = function()
			local host = vim.fn.input("Host [127.0.0.1]: ")
			host = host ~= "" and host or "127.0.0.1"
			local port = tonumber(vim.fn.input("Port [5678]: ")) or 5678
			return { host = host, port = port }
		end,
	},
}
