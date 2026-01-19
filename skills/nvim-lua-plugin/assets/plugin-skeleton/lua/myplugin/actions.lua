-- lua/myplugin/actions.lua
--
-- Put “real work” here, keep side effects explicit.

local M = {}

function M.do_thing(cfg, opts)
  if cfg.enabled == false then
    return
  end
  local msg = 'MyPlugin did the thing'
  if opts and opts.bang then
    msg = msg .. '!'
  end
  vim.notify(msg, cfg.notify_level)
end

return M
