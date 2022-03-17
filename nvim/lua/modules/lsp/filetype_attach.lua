local fa = {}

local auto_format = function(command)
  if not command then
    command = ":lua vim.lsp.buf.formatting_sync()"
  end
  vim.cmd(string.format(
    [[
    augroup lsp_buf_format
      au! BufWritePre <buffer>
      autocmd BufWritePre <buffer> %s
    augroup END
  ]],
    command
  ))
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
