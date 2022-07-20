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

local configurations = {
  go = { use = true, adapter = "go" },
  rust = { use = true, adapter = "lldb" },
}

for c, conf in pairs(configurations) do
  if not conf or not conf.use then
    return
  end

  local exist, adapter = pcall(require, "modules.dap.adapters." .. conf.adapter)
  if not exist then
    return
  end
  dap.adapters[conf.adapter] = adapter

  local conf_exist, configuration = pcall(
    require,
    "modules.dap.configurations." .. c
  )
  if not conf_exist then
    return
  end
  dap.configurations[c] = configuration
end

require("dap.ext.vscode").load_launchjs()
