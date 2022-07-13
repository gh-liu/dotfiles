local dap = require("dap")

vim.fn.sign_define(
  "DapBreakpoint",
  { text = "⬤", texthl = "RedSign", linehl = "", numhl = "" }
)
vim.fn.sign_define(
  "DapStopped",
  { text = "➔", texthl = "PurpleSign", linehl = "", numhl = "" }
)

dap.listeners.after.event_terminated["liu"] = function()
  dap.repl.close()
end
dap.listeners.before.event_exited["liu"] = function()
  dap.repl.close()
end

as.map("n", "<F4>", dap.terminate)
as.map("n", "<F5>", dap.continue)
as.map("n", "<F9>", dap.toggle_breakpoint)
as.map("n", "<F10>", dap.step_over)
as.map("n", "<F11>", dap.step_into)
as.map("n", "<F12>", dap.step_out)

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
