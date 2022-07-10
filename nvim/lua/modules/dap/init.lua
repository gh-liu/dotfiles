local dap = require("dap")

vim.fn.sign_define(
  "DapBreakpoint",
  { text = "⬤", texthl = "RedSign", linehl = "", numhl = "" }
)
vim.fn.sign_define(
  "DapStopped",
  { text = "➔", texthl = "PurpleSign", linehl = "", numhl = "" }
)
local dapClose = function()
  require("dap").disconnect()
  require("dap").repl.close()
  require("dap").close()

  local present, dapui = pcall(require, "dapui")
  if present then
    dapui.close()
  end
end
as.map("n", "<F4>", dapClose)
as.map("n", "<F5>", require("dap").continue)
as.map("n", "<F9>", require("dap").toggle_breakpoint)
as.map("n", "<F10>", require("dap").step_over)
as.map("n", "<F11>", require("dap").step_into)
as.map("n", "<F12>", require("dap").step_out)

local adapters = {
  go = true,
}

for ad, use in pairs(adapters) do
  if not use then
    return
  end

  local exist, config = pcall(require, "modules.dap.adapters." .. ad)
  if not exist then
    return
  end

  dap.adapters[ad] = config.adapter
  if config.configuration then
    dap.configurations[ad] = config.configuration
  end
end

require("dap.ext.vscode").load_launchjs()
