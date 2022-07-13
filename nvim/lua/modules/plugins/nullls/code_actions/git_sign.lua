local null_ls = require("null-ls")
local methods = require("null-ls.methods")
local CODE_ACTION = methods.internal.CODE_ACTION
local git_sign = {
  method = CODE_ACTION,
  filetypes = {},
  generator = {
    fn = function(params)
      local ok, gitsigns_actions = pcall(require("gitsigns").get_actions)
      if not ok or not gitsigns_actions then
        return
      end

      local name_to_title = function(name)
        return name:sub(1, 1):upper() .. name:gsub("_", " "):sub(2)
      end

      local actions = {}
      for name, action in pairs(gitsigns_actions) do
        -- I do not need the blame line action
        if name ~= "blame_line" then
          table.insert(actions, {
            title = name_to_title(name),
            action = function()
              vim.api.nvim_buf_call(params.bufnr, action)
            end,
          })
        end
      end
      return actions
    end,
  },
}
null_ls.register(git_sign)
