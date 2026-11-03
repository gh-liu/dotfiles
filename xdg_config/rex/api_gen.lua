-- Generate EmmyLua definitions from Rex's machine-readable API schema.
-- Run from the dotfiles root with:
--   rex do xdg_config/rex/api_gen.lua
-- Use output=/path/to/api.lua to inspect definitions without replacing the config copy.

local function fail(message)
  error("rex api generator: " .. message, 0)
end

local function command_output(argv)
  local result, err = rex.exec(argv)
  if result == nil then
    fail(err or "command failed to start")
  end
  if not result.ok then
    fail((result.stderr or "rex api list failed") .. " (exit " .. tostring(result.code) .. ")")
  end
  return result.stdout
end

local function shell_env(name, fallback)
  local value = os.getenv(name)
  if value == nil or value == "" then
    return fallback
  end
  return value
end

local function path_join(a, b)
  if a:sub(-1) == "/" then
    return a .. b
  end
  return a .. "/" .. b
end

local function lua_string(value)
  return string.format("%q", value)
end

local function pascal(value)
  local result = {}
  for part in value:gmatch("[^%._%-]+") do
    result[#result + 1] = part:sub(1, 1):upper() .. part:sub(2)
  end
  return table.concat(result)
end

local function method_type_name(name, suffix)
  return "Rex" .. pascal(name:gsub("%.", "_")) .. suffix
end

local function is_required(schema, key)
  for _, required in ipairs(schema.required or {}) do
    if required == key then
      return true
    end
  end
  return false
end

local function union_type(parts)
  local values, seen = {}, {}
  local function add(part)
    if type(part) == "table" then
      for _, item in ipairs(part) do
        add(item)
      end
    elseif not seen[part] then
      seen[part] = true
      values[#values + 1] = part
    end
  end
  add(parts)
  return table.concat(values, "|"), values
end

local function enum_type(schema)
  local values = {}
  for _, value in ipairs(schema.enum or {}) do
    if type(value) == "string" then
      values[#values + 1] = lua_string(value)
    elseif type(value) == "number" or type(value) == "boolean" then
      values[#values + 1] = tostring(value)
    end
  end
  if #values > 0 then
    return union_type(values)
  end
end

local function schema_type(schema, name, classes, emitted)
  if schema == nil then
    return "any"
  end

  local enum, enum_parts = enum_type(schema)
  if enum then
    return enum, enum_parts
  end

  if schema["$ref"] then
    return "table"
  end

  if schema.anyOf or schema.oneOf then
    local parts = {}
    for index, item in ipairs(schema.anyOf or schema.oneOf) do
      local item_type, item_parts = schema_type(item, name .. "Variant" .. index, classes, emitted)
      parts[#parts + 1] = item_parts or item_type
    end
    return union_type(parts)
  end

  if type(schema.type) == "table" then
    local parts = {}
    for _, kind in ipairs(schema.type) do
      local branch = {}
      for key, value in pairs(schema) do
        branch[key] = value
      end
      branch.type = kind
      local item_type, item_parts = schema_type(branch, name, classes, emitted)
      parts[#parts + 1] = item_parts or item_type
    end
    return union_type(parts)
  end

  if schema.type == "array" then
    local item_type, item_parts = schema_type(schema.items, name .. "Item", classes, emitted)
    if item_parts and #item_parts > 1 then
      item_type = "(" .. item_type .. ")"
    end
    return item_type .. "[]"
  end

  if schema.type == "object" or (schema.type == nil and schema.properties) then
    local class_name = name
    if not emitted[class_name] then
      emitted[class_name] = true
      local fields = {}
      for key, property in pairs(schema.properties or {}) do
        fields[#fields + 1] = {
          key = key,
          type = schema_type(property, class_name .. pascal(key), classes, emitted),
          optional = not is_required(schema, key),
          description = property.description
        }
      end
      table.sort(fields, function (a, b)
        return a.key < b.key
      end)
      classes[#classes + 1] = { name = class_name, fields = fields, description = schema.description }
    end
    return class_name
  end

  if schema.type == "string" then
    return "string"
  end
  if schema.type == "integer" then
    return "integer"
  end
  if schema.type == "number" then
    return "number"
  end
  if schema.type == "boolean" then
    return "boolean"
  end
  if schema.type == "null" then
    return "nil"
  end
  return "any"
end

local json = command_output({ "rex", "api", "list", "--json" })
local document, decode_error = rex.json.decode(json)
if document == nil then
  fail(decode_error or "invalid JSON returned by rex api list")
end

local function decode_command_json(argv, description)
  local output = command_output(argv)
  local value, error_message = rex.json.decode(output)
  if value == nil then
    fail(error_message or "invalid JSON returned by " .. description)
  end
  return value
end

-- Server actions do not include actions supplied by the connected GUI client,
-- such as pane.zoom. Prefer the first connected app client so the generated
-- alias matches the actions accepted by Rex.app.
local clients_document = decode_command_json({ "rex", "client", "ls", "--json" }, "rex client ls")
local client_id
for _, client in ipairs(clients_document.clients or {}) do
  if client.info and client.info.kind == "app" then
    client_id = client.client_id
    break
  end
end

local actions_argv = { "rex" }
if client_id then
  actions_argv[#actions_argv + 1] = "-C"
  actions_argv[#actions_argv + 1] = client_id
end
actions_argv[#actions_argv + 1] = "actions"
actions_argv[#actions_argv + 1] = "--json"

local actions_document = decode_command_json(actions_argv, "rex actions")
local action_names = {}
for _, action in ipairs(actions_document.actions or {}) do
  if type(action.name) == "string" then
    action_names[#action_names + 1] = action.name
  end
end
table.sort(action_names)

local classes = {}
local emitted = {}
local methods = {}
local methods_by_name = {}
for _, method in ipairs(document.methods or {}) do
  methods[#methods + 1] = method
  methods_by_name[method.name] = method
  method.input_type = schema_type(method.input_schema, method_type_name(method.name, "Args"), classes, emitted)
  method.output_type = schema_type(method.output_schema, method_type_name(method.name, "Result"), classes, emitted)
end
table.sort(methods, function(a, b) return a.name < b.name end)

local block_methods = {}
for _, block in ipairs(document.block_types or {}) do
  for _, method in ipairs(block.methods or {}) do
    local name = block.creator .. "." .. method.name
    block_methods[#block_methods + 1] = {
      name = name,
      creator = block.creator,
      member = method.name,
      input_schema = method.args_schema,
      input_type = schema_type(method.args_schema, method_type_name(name, "Args"), classes, emitted),
      output_type = schema_type(method.output_schema, method_type_name(name, "Result"), classes, emitted),
    }
  end
end
table.sort(block_methods, function(a, b) return a.name < b.name end)

local function method_signature(method, selector)
  local optional = #(method.input_schema and method.input_schema.required or {}) == 0 and "?" or ""
  return "fun(" .. (selector and selector .. ", " or "")
    .. "args: " .. method.input_type .. optional .. "): " .. method.output_type .. "|nil, string?"
end

-- Reflect values without calling host functions. Schema names also expose helpers
-- implemented through __index; unknown function signatures remain opaque.
local runtime_tables = {}
local function runtime_type(value, name, path)
  local kind = type(value)
  if kind == "function" then
    if path == "call" or path == "block.call" then
      local overloads = {}
      for _, method in ipairs(path == "call" and methods or block_methods) do
        local selector = path == "call" and "method: " .. lua_string(method.name)
          or "creator: " .. lua_string(method.creator) .. ", method: " .. lua_string(method.member)
        overloads[#overloads + 1] = method_signature(method, selector)
      end
      overloads[#overloads + 1] = "fun(...: any): any"
      classes[#classes + 1] = { name = name, fields = {}, overloads = overloads }
      return name
    end
    local method = methods_by_name[path]
    if method then
      -- The RPC schema does not describe defaults supplied by Lua wrappers.
      classes[#classes + 1] = {
        name = name,
        fields = {},
        overloads = { method_signature(method), "fun(...: any): any" },
      }
      return name
    end
    return "function"
  end
  if kind ~= "table" then return kind end
  if runtime_tables[value] then return runtime_tables[value] end
  runtime_tables[value] = name

  local class = { name = name, fields = {} }
  classes[#classes + 1] = class
  local keys, sources = {}, {}
  local function collect(source)
    if sources[source] then return end
    sources[source] = true
    for key in pairs(source) do
      if type(key) == "string" or type(key) == "number" then keys[key] = true end
    end
    local meta = getmetatable(source)
    if type(meta) == "table" and type(meta.__index) == "table" then collect(meta.__index) end
  end
  collect(value)
  local prefix = path == "" and "" or path .. "."
  for _, method in ipairs(methods) do
    if method.name:sub(1, #prefix) == prefix then
      local key = method.name:sub(#prefix + 1):match("^[^.]+")
      if key then keys[key] = true end
    end
  end
  local ordered = {}
  for key in pairs(keys) do ordered[#ordered + 1] = key end
  table.sort(ordered, function(a, b)
    if type(a) ~= type(b) then return type(a) < type(b) end
    return a < b
  end)
  for _, key in ipairs(ordered) do
    local member = value[key]
    if member ~= nil then
      local member_path = prefix .. tostring(key)
      class.fields[#class.fields + 1] = {
        key = key,
        type = runtime_type(member, name .. pascal(tostring(key)), member_path),
        description = methods_by_name[member_path] and methods_by_name[member_path].description,
      }
    end
  end
  local meta = getmetatable(value)
  if type(meta) == "table" and type(meta.__call) == "function" then
    class.overloads = { "fun(...: any): any" }
  end
  return name
end
runtime_type(rex, "RexRuntime", "")

table.sort(classes, function (a, b)
  return a.name < b.name
end)

local lines = {
  "---@meta", "", "-- Generated by xdg_config/rex/api_gen.lua.",
  "-- Do not edit this file directly; run the generator again after Rex updates.",
  "-- Runtime fields reflect this rex do environment; opaque host functions have no inferred signature.", ""
}

local function description(text)
  if text then
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
      lines[#lines + 1] = "---" .. line:gsub("\r$", "")
    end
  end
end

if #action_names > 0 then
  lines[#lines + 1] = "---@alias RexActionName"
  for _, action_name in ipairs(action_names) do
    lines[#lines + 1] = "---| " .. lua_string(action_name)
  end
  lines[#lines + 1] = ""
else
  lines[#lines + 1] = "---@alias RexActionName string"
  lines[#lines + 1] = ""
end

for _, class in ipairs(classes) do
  description(class.description)
  lines[#lines + 1] = "---@class " .. class.name
  for _, overload in ipairs(class.overloads or {}) do
    lines[#lines + 1] = "---@overload " .. overload
  end
  for _, field in ipairs(class.fields) do
    description(field.description)
    local optional = field.optional and "?" or ""
    local key
    if type(field.key) == "number" then
      key = "[" .. tostring(field.key) .. "]"
    else
      key = field.key:match("^[%a_][%w_]*$") and field.key or "[" .. lua_string(field.key) .. "]"
    end
    lines[#lines + 1] = "---@field " .. key .. optional .. " " .. field.type
  end
  lines[#lines + 1] = ""
end

lines[#lines + 1] = "---@type RexRuntime"
lines[#lines + 1] = "rex = rex"

local xdg = shell_env("XDG_CONFIG_HOME", path_join(shell_env("HOME", "."), ".config"))
local output_path = rex.args.output or path_join(path_join(xdg, "rex"), "api.lua")
local file, open_error = io.open(output_path, "w")
if not file then
  fail("cannot write " .. output_path .. ": " .. tostring(open_error))
end
-- Rex's Lua registry limits table.concat on large schemas. Write lines directly.
for _, line in ipairs(lines) do
  local written, write_error = file:write(line, "\n")
  if not written then
    file:close()
    fail("cannot write " .. output_path .. ": " .. tostring(write_error))
  end
end
local closed, close_error = file:close()
if not closed then
  fail("cannot close " .. output_path .. ": " .. tostring(close_error))
end

print("Generated " .. output_path .. " from " .. tostring(#methods)
  .. " Rex API methods and " .. tostring(#block_methods) .. " block methods")
