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
      child.lua([[require('myplugin').setup()]])
    end,
    post_once = function()
      child.stop()
    end,
  },
})

-- Example: test a specific action
T['action']['does something'] = function()
  -- Setup: put some text in buffer
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'line 1', 'line 2', 'line 3' })

  -- Act: call your plugin's action
  child.lua([[require('myplugin.actions').do_something()]])

  -- Assert: check the result
  local lines = child.api.nvim_buf_get_lines(0, 0, -1, true)
  expect.equality(lines[1], 'expected result')
end

-- Example: test error handling
T['action']['handles invalid input'] = function()
  expect.error(function()
    child.lua([[require('myplugin.actions').do_something(nil)]])
  end, 'expected error pattern')
end

-- Example: test with Plug mapping
T['Plug mapping']['works'] = function()
  -- Simulate user binding the Plug mapping
  child.api.nvim_set_keymap('n', '<leader>x', '<Plug>(MyPluginAction)', {})

  -- Setup buffer
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'test line' })

  -- Type the keys
  child.type_keys('<leader>x')

  -- Assert result
  -- ...
end

return T
