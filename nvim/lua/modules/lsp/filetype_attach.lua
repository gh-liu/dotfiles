-- local create_autocmd = vim.api.nvim_create_autocmd
local create_autocmd = vim.api.nvim_create_autocmd

local fa = {}

local auto_format = function(cmd)
  local opt = { buffer = 0, command = cmd }
  if cmd then
    opt.command = cmd
  else
    opt.callback = function()
      vim.lsp.buf.formatting_sync()
    end
  end

  create_autocmd("BufWritePre", opt)
end

fa.go = function(client)
  auto_format()
end

fa.rust = function(client)
  auto_format()
end

fa.lua = function(client)
  auto_format("lua require('modules.lang.lua.stylua').format()")
end

fa.json = function(client)
  auto_format()
end

local filetype_attach = setmetatable(fa, {
  __index = function()
    return function() end
  end,
})

return filetype_attach
