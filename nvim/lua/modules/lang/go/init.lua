local au = as.au
local cmd = vim.api.nvim_command
au.FileType = {
  "go",
  function()
    cmd(
      [[command! -bang    GoAlt  lua require("config.lang.go.alternate").switch("<bang>"=="!", '')]]
    )
    cmd(
      [[command! -bang    GoAltV lua require("config.lang.go.alternate").switch("<bang>"=="!", 'vsplit')]]
    )
    cmd(
      [[command! -bang    GoAltS lua require("config.lang.go.alternate").switch("<bang>"=="!", 'split')]]
    )

    cmd([[command!    GoLint  lua require("config.lang.go.lint").lint()]])

    cmd(
      [[command! GoAddTest      lua require("config.lang.go.test").fun_test()]]
    )
    cmd(
      [[command! GoAddExpTest   lua require("config.lang.go.test").exported_test()]]
    )
    cmd(
      [[command! GoAddAllTest   lua require("config.lang.go.test").all_test()]]
    )
  end,
}
