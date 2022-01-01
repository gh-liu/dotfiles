local cmd = vim.cmd
local o_s = vim.o
local map_key = vim.api.nvim_set_keymap

local M = {}

function M.opt(o, v, scopes)
  scopes = scopes or { o_s }
  for _, s in ipairs(scopes) do
    s[o] = v
  end
end

function M.autocmd(group, cmds, clear)
  clear = clear == nil and false or clear
  if type(cmds) == "string" then
    cmds = { cmds }
  end
  cmd("augroup " .. group)
  if clear then
    cmd([[au!]])
  end
  for _, c in ipairs(cmds) do
    cmd("autocmd " .. c)
  end
  cmd([[augroup END]])
end

function M.map(modes, lhs, rhs, opts)
  opts = opts or {}
  opts.noremap = opts.noremap == nil and true or opts.noremap
  if type(modes) == "string" then
    modes = { modes }
  end
  for _, mode in ipairs(modes) do
    map_key(mode, lhs, rhs, opts)
  end
end

function M.setup_auto_format(ft, command)
  if not command then
    command = "lua vim.lsp.buf.formatting_sync()"
  end
  cmd(string.format("autocmd BufWritePre *.%s %s", ft, command))
end

function M.smartquit()
  local buf_nums = vim.fn.len(vim.fn.getbufinfo({ buflisted = 1 }))

  if buf_nums == 1 then
    local ok = pcall(vim.cmd, ":silent quit")
    if not ok then
      local choice = vim.fn.input(
        "E37: Discard changes?  Y|y = Yes, N|n = No, W|w = Write and quit: "
      )
      if choice == "y" then
        vim.cmd("quit!")
      elseif choice == "w" then
        vim.cmd("write")
        vim.cmd("quit")
      else
        vim.fn.feedkeys("\\<ESC>")
      end
    end
  else
    local ok = pcall(vim.cmd, "bw")

    if not ok then
      local choice = vim.fn.input(
        "E37: Discard changes?  Y|y = Yes, N|n = No, W|w = Write and quit: "
      )
      if choice == "y" then
        vim.cmd("bw!")
      elseif choice == "w" then
        vim.cmd("write")
        vim.cmd("bw")
      else
        vim.fn.feedkeys("\\<ESC>")
      end
    end
  end
end

return M
