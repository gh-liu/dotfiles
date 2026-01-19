-- plugin/myplugin.lua
--
-- This file is executed eagerly at startup (see :h lua-plugin-lazy).
-- Keep it SMALL: only register commands, <Plug> mappings, and autocmds.
-- Defer require() of heavy modules until callbacks run (see :h lua-plugin-defer-require).

if vim.g.loaded_myplugin then
  return
end
vim.g.loaded_myplugin = true

vim.api.nvim_create_user_command('MyPluginDoThing', function(opts)
  local m = require('myplugin')
  m.do_thing({
    bang = opts.bang,
    args = opts.fargs,
  })
end, { bang = true, nargs = '*', desc = 'MyPlugin: do the thing' })

-- Expose <Plug> mapping so users can bind their own keys (see :h lua-plugin-keymaps).
vim.keymap.set('n', '<Plug>(MyPluginDoThing)', function()
  require('myplugin').do_thing({})
end, { silent = true })
