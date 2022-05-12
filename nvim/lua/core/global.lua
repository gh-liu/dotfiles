_G.as = {}

-- local cmd = vim.api.nvim_command

-- options
--
function as.opt(o, v, scopes)
  scopes = scopes or { vim.o }
  for _, s in ipairs(scopes) do
    s[o] = v
  end
end

-- mappings
--
function as.map(modes, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(modes, lhs, rhs, options)
end

-- user command
as.command = function(name, fn, opts)
  -- https://github.com/neovim/neovim/issues/14090#issuecomment-1094488198
  vim.api.nvim_create_user_command(name, fn, opts or {})
end

-- default option
--
function as._if_nil(val, default)
  if val == nil then
    return default
  end
  return val
end

-- treesitter
--
-- function as.node_at_cursor()
-- 	local line, col = table.unpack(vim.api.nvim_win_get_cursor(0))
-- 	return vim.treesitter.get_parser():parse()[1]:root():descendant_for_range(line - 1, col, line - 1, col + 1)
-- end

-- function as.parent_childs()
--   for node, field in as.node_at_cursor():parent():iter_children() do
--     print(node:type())
--   end
-- end

-- lazy require function
--
function as.lazy_require(module)
  local mt = {}

  mt.__index = function(_, key)
    if not mt._module then
      mt._module = require(module)
    end

    return mt._module[key]
  end

  mt.__newindex = function(_, key, val)
    if not mt._module then
      mt._module = require(module)
    end

    mt._module[key] = val
  end

  mt.__metatable = false

  return setmetatable({}, mt)
end

---Pretty print lua table
function as.dump(...)
  local objects = vim.tbl_map(vim.inspect, { ... })
  print(unpack(objects))
end
