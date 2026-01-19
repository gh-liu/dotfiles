-- Minimal reproducer for Neovim plugin issues.
--
-- Usage:
--   nvim --clean -u /path/to/this/init.lua
--
-- Then adjust the runtimepath to include your local plugin checkout.
-- NOTE: This file is a TEMPLATE; edit the path below.

vim.opt.runtimepath:append('/ABSOLUTE/PATH/TO/YOUR/PLUGIN')

-- Optional: keep UI noise minimal while debugging
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false

-- Example: user config for the plugin
pcall(function()
  require('myplugin').setup({
    enabled = true,
  })
end)

-- Example: a mapping to trigger functionality
vim.keymap.set('n', '<leader>x', '<Plug>(MyPluginDoThing)', { silent = true })
