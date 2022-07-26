local ok, _ = pcall(require, "toggleterm")
if not ok then
  return
end

local Terminal = require("toggleterm.terminal").Terminal:new({
  direction = "horizontal",
  float_opts = {
    border = "rounded",
  },
  on_open = function(term)
    vim.cmd("startinsert!")

    for _, value in ipairs({ "<a-t>", "<a-r>", "<a-f>" }) do
      vim.keymap.set("t", value, function()
        term:close()
      end, { buffer = term.bufnr })
    end

    vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], { buffer = term.bufnr })
    vim.keymap.set("n", "<esc>", function()
      term:close()
    end, { buffer = term.bufnr })
  end,
})

-- vim.keymap.set("n", "<a-r>", function()
--   local size = vim.o.columns * 0.4
--   Terminal:toggle(size, "vertical")
-- end)
-- vim.keymap.set("n", "<a-f>", function()
--   Terminal:toggle(nil, "float")
-- end)
-- vim.keymap.set("n", "<a-t>", function()
--   Terminal:toggle(20, "horizontal")
-- end)

return Terminal
