-- lua/myplugin/health.lua
--
-- :checkhealth myplugin will run this (see :h health-dev).

local config = require('myplugin.config')

local M = {}

M.check = function()
  vim.health.start('myplugin')

  local cfg = config.get()
  if type(cfg.enabled) == 'boolean' then
    vim.health.ok('config.enabled is boolean')
  else
    vim.health.error('config.enabled must be boolean', { 'Fix your setup({ enabled = ... })' })
  end

  if type(cfg.notify_level) == 'number' then
    vim.health.ok('config.notify_level is number')
  else
    vim.health.warn('config.notify_level should be number', { 'Example: vim.log.levels.INFO' })
  end
end

return M
