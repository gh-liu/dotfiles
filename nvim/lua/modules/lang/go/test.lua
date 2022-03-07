local M = {}

local vimm = vim

-- bin
local gotests = "gotests"
-- template
local test_template = ""
local test_template_dir = ""

local run_cmd = function(parallel, options)
  parallel = parallel or false
  options = options or {}

  local args = { gotests, "-w" }

  for _, v in ipairs(options) do
    table.insert(args, v)
  end

  if parallel then
    table.insert(args, "-parallel")
  end

  -- PATH
  local gofile = vimm.fn.expand("%")
  table.insert(args, gofile)

  local use_template_dir = false
  if string.len(test_template_dir) > 1 then
    table.insert(args, "-template_dir")
    table.insert(args, test_template_dir)
    use_template_dir = true
  end

  if not use_template_dir and string.len(test_template) > 1 then
    table.insert(args, "-template")
    table.insert(args, test_template)
  end

  vimm.fn.jobstart(args, {
    on_stdout = function(_, data, _)
      -- print("gotests " .. vimm.inspect(data))
    end,
    on_stderr = function(_, data, _)
      -- print("gotests: " .. "error: " .. vimm.inspect(data))
    end,
  })
end

M.fun_test = function(parallel)
  parallel = parallel or false

  -- local row, col = table.unpack(vimm.api.nvim_win_get_cursor(0))
  -- row, col = row + 1, col + 1

  -- get the word under cursor
  -- TODO: use tree-sitter
  local funcname = vimm.fn.expand("<cword>")

  local opts = { "-only", funcname }
  run_cmd(parallel, opts)
end

M.all_test = function(parallel)
  parallel = parallel or false

  local opts = { "-all" }
  run_cmd(parallel, opts)
end

M.exported_test = function(parallel)
  parallel = parallel or false
  local opts = { "-exported" }
  run_cmd(parallel, opts)
end

return M
