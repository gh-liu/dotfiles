local create_autocmd = vim.api.nvim_create_autocmd

local cmd = vim.api.nvim_command

create_autocmd("FileType", {
  callback = function()
    cmd(
      [[command! -bang    GoAlt  lua require("modules.lang.go.alternate").switch("<bang>"=="!", '')]]
    )
    cmd(
      [[command! -bang    GoAltV lua require("modules.lang.go.alternate").switch("<bang>"=="!", 'vsplit')]]
    )
    cmd(
      [[command! -bang    GoAltS lua require("modules.lang.go.alternate").switch("<bang>"=="!", 'split')]]
    )

    cmd([[command!    GoLint  lua require("modules.lang.go.lint").run()]])

    cmd(
      [[command! GoAddTest      lua require("modules.lang.go.test").fun_test()]]
    )
    cmd(
      [[command! GoAddExpTest   lua require("modules.lang.go.test").exported_test()]]
    )
    cmd(
      [[command! GoAddAllTest   lua require("modules.lang.go.test").all_test()]]
    )

    cmd(
      [[command! -nargs=* -range GoAddTags lua require("modules.lang.go.tags").add(<f-args>)]]
    )
    cmd(
      [[command! -nargs=* -range GoRemoveTags lua require("modules.lang.go.tags").rm(<f-args>)]]
    )
  end,
})
