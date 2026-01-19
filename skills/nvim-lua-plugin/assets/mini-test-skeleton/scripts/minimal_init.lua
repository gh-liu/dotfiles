-- Minimal init.lua for running mini.test
-- Usage: nvim --headless -u scripts/minimal_init.lua -c "lua MiniTest.run()"

-- Add mini.nvim to runtimepath (adjust path as needed)
vim.cmd([[
  set runtimepath+=deps/mini.nvim
  " Or if installed globally:
  " set runtimepath+=~/.local/share/nvim/site/pack/*/start/mini.nvim
]])

-- Add current plugin to runtimepath
vim.cmd([[set runtimepath+=.]])

-- Setup mini.test
require('mini.test').setup()
