local fa = {}

local auto_format = function(cmd)
  if not cmd then
    cmd = ":lua vim.lsp.buf.formatting_sync()"
  end

  local lsp_buf_format = vim.api.nvim_create_augroup(
    "lsp_buf_format",
    { clear = true }
  )

  vim.api.nvim_create_autocmd(
    "BufWritePre",
    { buffer = 0, command = cmd, group = lsp_buf_format }
  )
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
