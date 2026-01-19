-- lua/myplugin/config.lua
--
-- setup(opts) should only merge configuration and do light validation.
-- Avoid heavy initialization and I/O here (see :h lua-plugin-init).

local M = {}

local defaults = {
  enabled = true,
  notify_level = vim.log.levels.INFO,
}

local state = vim.deepcopy(defaults)

local function validate(opts)
  vim.validate('opts', opts, 'table', true)
  if not opts then
    return
  end
  vim.validate('enabled', opts.enabled, 'boolean', true)
  vim.validate('notify_level', opts.notify_level, 'number', true)
end

function M.setup(opts)
  validate(opts)
  state = vim.tbl_deep_extend('force', vim.deepcopy(defaults), opts or {})
end

function M.get()
  return state
end

function M.defaults()
  return defaults
end

return M
