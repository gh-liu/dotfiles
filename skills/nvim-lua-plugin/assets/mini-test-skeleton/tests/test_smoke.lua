-- Smoke tests for myplugin
-- Run: nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run_file('tests/test_smoke.lua')"

local MiniTest = require('mini.test')
local expect = MiniTest.expect

-- Create test set
local T = MiniTest.new_set()

-- Create child Neovim for isolated testing
local child = MiniTest.new_child_neovim()

-- Hooks: start child before tests, stop after all tests
T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'scripts/minimal_init.lua' })
      -- Wait for child to be ready
      child.bo.readonly = false
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- Test: plugin loads without error
T['plugin loads'] = function()
  -- This should not throw
  child.lua([[require('myplugin')]])
end

-- Test: setup() works with default config
T['setup with defaults'] = function()
  child.lua([[require('myplugin').setup()]])
end

-- Test: setup() merges user config
T['setup merges config'] = function()
  child.lua([[require('myplugin').setup({ some_option = true })]])
  local config = child.lua_get([[require('myplugin.config').options]])
  expect.equality(config.some_option, true)
end

-- Test: user command exists after loading
T['command exists'] = function()
  child.lua([[require('myplugin')]])
  local cmds = child.api.nvim_get_commands({})
  -- Replace 'MyPluginCmd' with your actual command name
  expect.equality(cmds['MyPluginCmd'] ~= nil, true)
end

return T
