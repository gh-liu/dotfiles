-- entry buffer -> get line infos (ag) -> set ext_marks -> save cmds ->run cmd
-- build tags:  -tags
-- compile: -c -o
-- timeout: -timeout=%s

-- execute vsplit . ' __test_term__'

local M = {}

local options = {}
options.line_infos = function() end

local unpack = unpack or table.unpack

local ns_id = vim.api.nvim_create_namespace("extmark_for_go_test")
local highlight = "LspCodeLens"
local cmds = {}

local save_cmds = function(mark_id, line)
  table.insert(cmds, {
    id = mark_id,
    cmd = line,
  })
end

local clear_buf_extmarks = function()
  -- Get all marks in this buffer + namespace.
  local all = vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {})

  for _, v in ipairs(all) do
    local id, _, _ = unpack(v)
    -- Clean extmark
    vim.api.nvim_buf_del_extmark(0, ns_id, id)
  end
end

local set_extmark = function(line)
  local line_num = line.lnum - 1
  local col_num = line.col

  local opts = {
    virt_text = {
      { "run test", highlight },
    },
    virt_text_pos = "eol",
    hl_mode = "combine",
  }

  local mark_id = vim.api.nvim_buf_set_extmark(
    0,
    ns_id,
    line_num,
    col_num,
    opts
  )

  return mark_id
end

local process_lines = function(lines)
  local results = {}
  for _, line in pairs(lines) do
    local file, row, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
    if file then
      local item = {
        filename = file,
        lnum = tonumber(row),
        col = tonumber(col),
        line = text,
      }
      table.insert(results, item)
    end
  end
  return results
end

M.refresh = function()
  local fname = vim.fn.expand("%:p")

  local rg_cmd = "rg"
  local rg_args = {
    "--color=never",
    "--no-heading",
    "--with-filename",
    "--line-number",
    "--column",
    "func (Test|Examp|Bench|Fuzz)",
    fname,
  }

  local ok, Job = pcall(require, "plenary.job")
  if not ok then
    return
  end

  -- stylua: ignore start
  Job:new({
      command = rg_cmd,
      args = rg_args,
      on_exit = vim.schedule_wrap(function(j, code)
        if code == 2 then
          local error = table.concat(j:stderr_result(), "\n")
          print(error)
          return
        end

        if code == 1 then
          return
        end

        local lines = j:result()

        local res = process_lines(lines)

        -- clean extmarks
        if #cmds >0 then
            cmds = {}
            clear_buf_extmarks()
        end

        for _, v in ipairs(res) do
            local mark_id = set_extmark(v)
            save_cmds(mark_id,v)
        end

      end),
    }):start()
  -- stylua: ignore end
end

M.run = function()
  print(vim.inspect(cmds))
end

M.setup = function(opts)
  opts = opts or options

  -- lua require("modules.lang.go.run_test").refresh()
  -- lua require("modules.lang.go.run_test").run()
end

local run_term = function(cmd)
  -- vim.fn.term_start(, options: any)
end

return M
