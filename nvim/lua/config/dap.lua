local dap = require('dap')

-- Neovim Lua
dap.adapters.nlua = function(callback, config)
    callback {
        type = 'server',
        host = config.host,
        port = config.port
    }
end

dap.configurations.lua = {{
    type = 'nlua',
    request = 'attach',
    name = 'Attach to running Neovim instance',
    host = function()
        local value = vim.fn.input 'Host [127.0.0.1]: '
        if value ~= '' then
            return value
        end
        return '127.0.0.1'
    end,
    port = function()
        local val = tonumber(vim.fn.input 'Port: ')
        assert(val, 'Please provide a port number')
        return val
    end
}}

dap.adapters.go = function(callback, config)
    local stdout = vim.loop.new_pipe(false)
    local handle
    local pid_or_err
    local port = 38697
    local opts = {
        stdio = {nil, stdout},
        args = {"dap", "-l", "127.0.0.1:" .. port},
        detached = true
    }
    handle, pid_or_err = vim.loop.spawn("dlv", opts, function(code)
        stdout:close()
        handle:close()
        if code ~= 0 then
            print('dlv exited with code', code)
        end
    end)
    assert(handle, 'Error running dlv: ' .. tostring(pid_or_err))
    stdout:read_start(function(err, chunk)
        assert(not err, err)
        if chunk then
            vim.schedule(function()
                require('dap.repl').append(chunk)
            end)
        end
    end)
    -- Wait for delve to start
    vim.defer_fn(function()
        callback({
            type = "server",
            host = "127.0.0.1",
            port = port
        })
    end, 100)
end
-- https://github.com/go-delve/delve/blob/master/Documentation/usage/dlv_dap.md
dap.configurations.go = {{
    type = "go",
    name = "Debug",
    request = "launch",
    program = "${file}"
}, {
    type = "go",
    name = "Debug test", -- configuration for debugging test files
    request = "launch",
    mode = "test",
    program = "${file}"
}, -- works with go.mod packages and sub packages 
{
    type = "go",
    name = "Debug test (go.mod)",
    request = "launch",
    mode = "test",
    program = "./${relativeFileDirname}"
}}
