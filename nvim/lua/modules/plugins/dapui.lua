require("dapui").setup({
  icons = { expanded = "▾", collapsed = "▸" },
  mappings = {
    -- Use a table to apply multiple mappings
    expand = { "<CR>", "<2-LeftMouse>" },
    open = "o",
    remove = "d",
    edit = "e",
    repl = "r",
    toggle = "t",
  },
  -- Expand lines larger than the window
  -- Requires >= 0.7
  expand_lines = vim.fn.has("nvim-0.7"),
  -- Layouts define sections of the screen to place windows.
  -- The position can be "left", "right", "top" or "bottom".
  -- The size specifies the height/width depending on position. It can be an Int
  -- or a Float. Integer specifies height/width directly (i.e. 20 lines/columns) while
  -- Float value specifies percentage (i.e. 0.3 - 30% of available lines/columns)
  -- Elements are the elements shown in the layout (in order).
  -- Layouts are opened in order so that earlier layouts take priority in window sizing.
  layouts = {
    {
      elements = {
        -- Elements can be strings or table with id and size keys.
        { id = "scopes", size = 0.25 },
        "breakpoints",
        "stacks",
        -- "watches",
      },
      size = 40, -- 40 columns
      position = "left",
    },
    -- {
    --   elements = {
    --     "repl",
    --     "console",
    --   },
    --   size = 0.25, -- 25% of total lines
    --   position = "bottom",
    -- },
  },
  floating = {
    max_height = 0.9, -- These can be integers or a float between 0 and 1.
    max_width = 0.5, -- Floats will be treated as percentage of your screen.
    border = gh.lazy_require("core.config").border.rounded, -- Border style. Can be "single", "double" or "rounded"
    mappings = {
      close = { "q", "<Esc>" },
    },
  },
})

-- UI
local dap = require("dap")
local dapui = require("dapui")
dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

local mappings = {
  ["<M-c>"] = dap.continue,
  ["<M-right>"] = dap.step_over,
  ["<M-down>"] = dap.step_into,
  ["<M-up>"] = dap.step_out,
  ["<M-x>"] = dap.toggle_breakpoint,
  ["<M-t>"] = function()
    dapui.toggle({ reset = true })
  end,
  ["<M-k>"] = dapui.eval,
  ["<M-m>"] = dapui.float_element,
  ["<M-v>"] = function()
    dapui.float_element("scopes")
  end,
  ["<M-r>"] = function()
    dapui.float_element("repl")
  end,
  ["<M-q>"] = dap.terminate,
}
for keys, fn in pairs(mappings) do
  gh.map("n", keys, fn, { noremap = true })
end
