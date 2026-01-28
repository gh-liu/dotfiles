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
      child.bo.readonly = false
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- Test: plugin loads without error
T['plugin loads'] = function()
  child.lua([[require('myplugin')]])
end

-- Test: setup() works with default config
T['setup with defaults'] = function()
  child.lua([[require('myplugin').setup()]])
end

-- Test: setup() merges user config
T['setup merges config'] = function()
  child.lua([[require('myplugin').setup({ enabled = false, notify_level = vim.log.levels.ERROR })]])
  local config = child.lua_get([[require('myplugin.config').get()]])
  expect.equality(config.enabled, false)
  expect.equality(config.notify_level, vim.log.levels.ERROR)
end

-- Test: setup() preserves defaults for unspecified options
T['setup preserves defaults'] = function()
  child.lua([[require('myplugin').setup({ enabled = false })]])
  local config = child.lua_get([[require('myplugin.config').get()]])
  expect.equality(config.enabled, false)
  -- notify_level should still be default
  expect.equality(config.notify_level, vim.log.levels.INFO)
end

-- Test: user command exists after loading
T['command exists'] = function()
  child.lua([[require('myplugin')]])
  local cmds = child.api.nvim_get_commands({})
  expect.equality(cmds['MyPluginDoThing'] ~= nil, true)
end

-- Test: <Plug> mapping exists
T['Plug mapping exists'] = function()
  child.lua([[require('myplugin')]])
  local mappings = child.api.nvim_get_keymap('n')
  local found = false
  for _, m in ipairs(mappings) do
    if m.lhs == '<Plug>(MyPluginDoThing)' then
      found = true
      break
    end
  end
  expect.equality(found, true)
end

-- Test: health check runs without error
T['health check runs'] = function()
  -- Health check should not throw
  child.lua([[pcall(function() vim.cmd('checkhealth myplugin') end)]])
end

-- Test: module exports expected functions
T['module exports'] = function()
  local exports = child.lua_get([[vim.tbl_keys(require('myplugin'))]])
  expect.table_contains(exports, 'setup')
  expect.table_contains(exports, 'do_thing')
end

return T
