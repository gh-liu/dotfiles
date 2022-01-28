vim.cmd([[command! -bang    GoAlt  lua require("config.lang.go.alternate").switch("<bang>"=="!", '')]])
vim.cmd([[command! -bang    GoAltV lua require("config.lang.go.alternate").switch("<bang>"=="!", 'vsplit')]])
vim.cmd([[command! -bang    GoAltS lua require("config.lang.go.alternate").switch("<bang>"=="!", 'split')]])

vim.cmd([[command!    GoLint  lua require("config.lang.go.lint").lint()]])

vim.cmd([[command! GoAddTest      lua require("config.lang.go.test").fun_test()]])
vim.cmd([[command! GoAddExpTest   lua require("config.lang.go.test").exported_test()]])
vim.cmd([[command! GoAddAllTest   lua require("config.lang.go.test").all_test()]])
