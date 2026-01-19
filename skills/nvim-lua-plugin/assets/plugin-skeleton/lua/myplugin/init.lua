-- lua/myplugin/init.lua
--
-- Public API surface. Keep it stable and small.

local config = require('myplugin.config')
local actions = require('myplugin.actions')

local M = {}

M.setup = config.setup

function M.do_thing(opts)
  return actions.do_thing(config.get(), opts or {})
end

return M
