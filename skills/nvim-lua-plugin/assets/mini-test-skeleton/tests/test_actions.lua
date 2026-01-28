-- Action/functionality tests for myplugin
-- Run: nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run_file('tests/test_actions.lua')"

local MiniTest = require('mini.test')
local expect = MiniTest.expect

local T = MiniTest.new_set()
local child = MiniTest.new_child_neovim()

T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'scripts/minimal_init.lua' })
      child.lua([[require('myplugin').setup({ enabled = true, notify_level = vim.log.levels.INFO })]])
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- Test: command executes without error
T['command executes'] = function()
  child.cmd('MyPluginDoThing')
end

-- Test: command with bang works
T['command with bang'] = function()
  child.cmd('MyPluginDoThing!')
end

-- Test: command with arguments
T['command with args'] = function()
  child.cmd('MyPluginDoThing arg1 arg2')
end

-- Test: calling Lua API directly
T['Lua API works'] = function()
  child.lua([[require('myplugin').do_thing({ bang = true, args = {'test'} })]])
end

-- Test: disabled config prevents execution
T['disabled config no-ops'] = function()
  child.lua([[require('myplugin').setup({ enabled = false })]])
  child.lua([[require('myplugin').do_thing({})]])
end

-- Test: <Plug> mapping can be triggered
T['Plug mapping callable'] = function()
  child.lua([[vim.keymap.set('n', 'x', '<Plug>(MyPluginDoThing)', { buffer = 0 })]])
  child.lua([[vim.api.nvim_feedkeys('x', 'nx', false)]])
end

-- Example: test a specific buffer action
T['action']['modifies buffer'] = function()
  -- Setup: put some text in buffer
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'line 1', 'line 2', 'line 3' })

  -- Act: call your plugin's action
  -- child.lua([[require('myplugin.actions').do_something()]])

  -- Assert: check the result
  local lines = child.api.nvim_buf_get_lines(0, 0, -1, true)
  expect.equality(lines[1], 'line 1')
end

-- Example: test error handling
T['action']['handles invalid input'] = function()
  expect.error(function()
    child.lua([[error('test error')]])
  end, 'test error')
end

-- Example: test with Plug mapping
T['Plug mapping']['works'] = function()
  -- Simulate user binding the Plug mapping
  child.api.nvim_set_keymap('n', '<leader>x', '<Plug>(MyPluginDoThing)', {})

  -- Setup buffer
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'test line' })

  -- Type the keys
  child.type_keys('<leader>x')
end

return T
