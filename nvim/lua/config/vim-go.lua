-- local utils = require('utils')
-- local map = utils.map
-- local autocmd = utils.autocmd
-- disable gopls
vim.g.go_gopls_enabled = 0
-- Go syntax highlighting
-- vim.g.go_highlight_types = 1
-- vim.g.go_highlight_fields = 1
-- vim.g.go_highlight_functions = 1
-- vim.g.go_highlight_function_calls = 1
-- vim.g.go_highlight_extra_types = 1
-- vim.g.go_highlight_operators = 1
-- vim.g.go_highlight_generate_tags = 1
-- vim.g.go_highlight_build_constraints = 1
vim.g.go_highlight_debug = 0

-- Status line types/signatures
vim.g.go_auto_type_info = 0

-- disable K
vim.g.go_doc_keywordprg_enabled = 0

-- complete by nvim-lsp
vim.g.go_code_completion_enabled = 0

-- disable the default mapping of CTRL-]
vim.g.go_def_mapping_enabled = 0

vim.g.go_test_show_name = 1
vim.g.go_debug_preserve_layout = 1

-- run go imports on file save
-- vim.g.go_fmt_command = "goimports"

