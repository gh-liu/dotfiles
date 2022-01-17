vim.cmd([[command! -bang    GoAlt  lua require"config.lang.go.alternate".switch("<bang>"=="!", '')]])
vim.cmd([[command! -bang    GoAltV lua require"config.lang.go.alternate".switch("<bang>"=="!", 'vsplit')]])
vim.cmd([[command! -bang    GoAltS lua require"config.lang.go.alternate".switch("<bang>"=="!", 'split')]])
