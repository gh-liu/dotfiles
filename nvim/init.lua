pcall(require, "impatient")

require("core.global")

require("core.options")

require("core.keymaps")

require("core.autocmd")

require("core.command")

require("core.colorscheme")

require("core.disable_builtin")

require("modules.statusline")

-- plugins settings
require("modules.plugins")

-- lsp settings
require("modules.lsp")

-- lang settings
require("modules.lang.go")
