-- log.lua
--
-- Inspired by rxi/log.lua

local M = {}

M.highlights = true
M.use_console = true
M.outfile = nil
M.level = "trace"

local modes = {
  { name = "trace", hl = "Comment" },
  { name = "debug", hl = "Comment" },
  { name = "info", hl = "None" },
  { name = "warn", hl = "WarningMsg" },
  { name = "error", hl = "ErrorMsg" },
  { name = "fatal", hl = "ErrorMsg" },
}

local levels = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
end

local function log(level_idx, level, msg_maker, ...)
  -- Return early if we're below the log level
  if level_idx < levels[M.level] then
    return
  end

  local levelnameupper = level.name:upper()
  local info = debug.getinfo(2, "Sl")
  local lineinfo = info.short_src .. ":" .. info.currentline
  local msg = msg_maker(...)

  -- Output to log file
  if M.outfile then
    local fp = io.open(M.outfile, "a")
    local str = string.format(
      "[%-6s%s] %s: %s\n",
      levelnameupper,
      os.date(),
      lineinfo,
      msg
    )
    fp:write(str)
    fp:close()
  end

  -- Output to console
  if M.use_console then
    local str = string.format(
      "[%-6s%s] %s: %s",
      levelnameupper,
      os.date("%H:%M:%S"),
      lineinfo,
      msg
    )

    if M.highlights and level.hl then
      vim.cmd(string.format("echohl %s", level.hl))
    end

    local split_console = vim.split(str, "\n")
    for _, v in ipairs(split_console) do
      vim.cmd(string.format([[echom "%s"]], vim.fn.escape(v, '"')))
    end

    if M.highlights and level.hl then
      vim.cmd("echohl NONE")
    end
  end
end

local function make_string(...)
  local round = function(x, increment)
    increment = increment or 1
    x = x / increment
    return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
  end

  local t = {}
  for i = 1, select("#", ...) do
    local x = select(i, ...)

    if type(x) == "number" then
      x = round(x, 0.01)
    elseif type(x) == "table" then
      x = vim.inspect(x)
    else
      x = tostring(x)
    end

    t[#t + 1] = x
  end

  return table.concat(t, " ")
end

local function make_format_string(...)
  local args = { ... }
  local fmt_str = table.remove(args, 1)
  local inspected = {}
  for _, v in ipairs(args) do
    table.insert(inspected, vim.inspect(v))
  end
  return string.format(fmt_str, unpack(inspected))
end

for i, x in ipairs(modes) do
  M[x.name] = function(...)
    return log(i, x, make_string, ...)
  end

  M[("%sf"):format(x.name)] = function(...)
    return log(i, x, make_format_string, ...)
  end
end

return M
