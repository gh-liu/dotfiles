local Job = require("plenary.job")

local M = {}

M.run = function()
  --   print("Running now:", root)

  local lint_exe = "golangci-lint"

  local lint_args = {
    "run",
    -- "-c", ".golangci.yml",
    "--out-format",
    "json",
  }

  local j = Job:new({
    command = lint_exe,

    args = lint_args,

    -- cwd = root,

    on_exit = vim.schedule_wrap(function(self)
      print("Complete!")
      local output = self:result()
      local issues = vim.fn.json_decode(output).Issues

      if not issues or vim.tbl_isempty(issues) then
        print("[golangci lint] No Issues")
        return
      end

      local results = {}
      for _, issue in ipairs(issues) do
        table.insert(results, {
          filename = issue.Pos.Filename,
          lnum = issue.Pos.Line,
          text = issue.Text,
        })
      end

      vim.fn.setqflist(results)
      vim.cmd([[copen]])
    end),
  })

  j:start()

  --   return root
end

return M
