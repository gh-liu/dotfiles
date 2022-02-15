_G.as = {}

-- create global variables for config file
local ok, config = pcall(require, "config")
if ok then
  for k, v in pairs(config) do
    local key = "code_" .. k
    if not vim.g[key] then
      if string.match(k, "themes") then
        vim.g[k] = v
      end
      vim.g[key] = v
    end
  end
end

-- options
function as.opt(o, v, scopes)
  scopes = scopes or { vim.o }
  for _, s in ipairs(scopes) do
    s[o] = v
  end
end

-- mappings
function as.map(modes, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end

  if type(modes) == "string" then
    modes = { modes }
  end

  for _, mode in ipairs(modes) do
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
  end
end

-- autocommands
-- function as.nvim_set_au(au_type, where, dispatch)
--   vim.cmd(string.format("au! %s %s %s", au_type, where, dispatch))
-- end

function as.autocmd(group, cmds, clear)
  clear = clear == nil and false or clear
  if type(cmds) == "string" then
    cmds = { cmds }
  end
  vim.cmd("augroup " .. group)
  if clear then
    vim.cmd([[au!]])
  end
  for _, c in ipairs(cmds) do
    vim.cmd("autocmd " .. c)
  end
  vim.cmd([[augroup END]])
end

-- lsp
function as.is_lsp_autostart(server)
  local blacklist = vim.g.self_lsp_autostart_blacklist
  if blacklist == nil or #blacklist < 1 then
    return true
  end
  for _, v in pairs(blacklist) do
    if server == v then
      return false
    end
  end
  return true
end

-- default option
function as._default_bool(val, default)
  if val == true or val == nil and default == nil then
    return true
  elseif val == false and default == nil then
    return false
  end
  return default
end

function as._default_num(val, default)
  if val == nil or not tonumber(val) or val <= 0 then
    return default
  end
  return val
end

function as._if_nil(val, default)
  if val == nil then
    return default
  end
  return val
end

-- pretty print wrapper for lua tables
function as.pprint(...)
  local objects = vim.tbl_map(vim.inspect, { ... })
  print(unpack(objects))
end

function as.node_at_cursor()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return vim.treesitter.get_parser()
    :parse()[1]
    :root()
    :descendant_for_range(line - 1, col, line - 1, col + 1)
end

function as.parent_childs()
  for node, field in as.node_at_cursor():parent():iter_children() do
    print(node:type())
  end
end
