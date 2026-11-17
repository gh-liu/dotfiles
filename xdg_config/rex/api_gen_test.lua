-- Run from the dotfiles root: rex do xdg_config/rex/api_gen_test.lua
local output_path = os.tmpname()
local schema = {
  methods = {
    {
      name = "session.view",
      description = "Read a session.\nDoes not change it.",
      input_schema = {
        type = "object",
        required = { "session_id", "limit" },
        properties = {
          action = { type = "integer" },
          session_id = { type = "string" },
          limit = { type = "integer" },
        },
      },
      output_schema = {
        type = "object",
        required = { "values", "choice", "label" },
        properties = {
          values = { type = { "null", "array" }, items = { type = "integer" } },
          label = { type = { "string", "null" }, description = "A label.\nMay be absent." },
          mixed = {
            type = "array",
            items = {
              anyOf = {
                { type = "string" },
                { anyOf = { { type = "integer" }, { type = "string" } } },
              },
            },
          },
          choice = {
            oneOf = {
              { type = "object", properties = { left = { type = "string" } } },
              { type = "object", properties = { right = { type = "integer" } } },
            },
          },
          metadata = {
            type = { "null", "object" },
            properties = { enabled = { type = "boolean" } },
          },
        },
      },
    },
    {
      name = "session.list",
      input_schema = { type = "object" },
      output_schema = { type = "object" },
    },
    {
      name = "server.apple.privacy_status",
      input_schema = { type = "object" },
      output_schema = { type = "object" },
    },
  },
  block_types = {
    {
      creator = "com.example.terminal",
      methods = {
        {
          name = "title",
          args_schema = { type = "object", properties = { limit = { type = "integer" } }, required = { "limit" } },
          output_schema = { type = "object", properties = { title = { type = "string" } } },
        },
      },
    },
  },
}

local function generate()
  local generator = assert(loadfile("xdg_config/rex/api_gen.lua"))
  local function host_function() error("runtime discovery must not invoke host functions") end
  local runtime = {
    args = { output = output_path },
    json = rex.json,
    session = setmetatable({}, { __index = function(_, key) return key == "view" and host_function or nil end }),
    block = { call = host_function },
    client = { queue = host_function },
    bind = host_function,
    invoke = host_function,
    newly_added = { run = host_function, enabled = true },
    inherited = setmetatable({}, { __index = { delegated = host_function } }),
    callable = setmetatable({}, { __call = host_function }),
    call = host_function,
    exec = function(argv)
      local document = argv[2] == "api" and schema
        or argv[2] == "client" and { clients = {} }
        or { actions = {
          { name = "pane.zoom" },
          { name = "future.action", args = {
            type = "object", required = { "choice" }, properties = {
              choice = { type = "string", enum = { "new_choice", "other_choice" }, description = "Choices supplied by Rex." },
            },
          } },
          { name = "client.setting.interface.panes.density", args = {
            type = "object", properties = { value = { type = "string", enum = { "comfortable", "compact" } } },
          } },
          { name = "client.setting.terminal.typography.font", args = {
            type = "object", required = { "value" }, properties = { value = { type = "string" } },
          } },
          { name = "client.setting.terminal.typography.size", args = {
            type = "object", properties = { value = { type = "number" }, increase = { type = "integer" } },
          } },
        } }
      return { ok = true, stdout = assert(rex.json.encode(document)) }
    end,
  }
  runtime.newly_added.root = runtime
  setfenv(generator, setmetatable({
    rex = runtime,
    -- Redirect even the old generator's default path: never touch the user's api.lua.
    io = { open = function(_, mode) return io.open(output_path, mode) end },
    print = function() end,
  }, { __index = _G }))
  generator()
  local file = assert(io.open(output_path))
  local output = file:read("*a")
  file:close()
  return output
end

local ok, err = pcall(function()
  local output = generate()
  local function contains(text)
    assert(output:find(text, 1, true), "missing annotation: " .. text)
  end
  contains("---@field values nil|integer[]")
  contains("---@field label string|nil")
  contains("---@field action? integer")
  contains("---@field mixed? (string|integer)[]")
  contains("---@field choice RexSessionViewResultChoiceVariant1|RexSessionViewResultChoiceVariant2")
  contains("---@field left? string")
  contains("---@field right? integer")
  contains("---@field metadata? nil|RexSessionViewResultMetadata")
  contains("---A label.\n---May be absent.\n---@field label")
  contains("---Read a session.\n---Does not change it.")
  contains("---@field view RexRuntimeSessionView")
  contains("---@class RexRuntimeSessionView\n---@overload fun(args: RexSessionViewArgs): RexSessionViewResult|nil, string?")
  contains("---@field bind RexRuntimeBind")
  contains("---@field invoke RexRuntimeInvoke")
  contains('---@overload fun(key: string, action: "future.action", args: RexFutureActionActionArgs)')
  contains('---@overload fun(action: "future.action", args: RexFutureActionActionArgs): any|nil, string?')
  contains('---@overload fun(action: "future.action", args: RexFutureActionActionArgs)')
  contains('---Choices supplied by Rex.\n---@field choice "new_choice"|"other_choice"')
  contains('---@overload fun(key: string, fn: function)')
  contains('---@overload fun(action: "client.setting.interface.panes.density", args: RexClientSettingInterfacePanesDensityActionArgs?)')
  contains('---@overload fun(action: "client.setting.terminal.typography.font", args: RexClientSettingTerminalTypographyFontActionArgs)')
  contains('---@field value? "comfortable"|"compact"')
  contains('---@field value string')
  contains('---@field value? number')
  contains('---@field increase? integer')
  contains('---@field queue RexRuntimeClientQueue')
  contains("---@field newly_added RexRuntimeNewlyAdded")
  contains("---@field run function")
  contains("---Exported by Rex; no signature schema is available.\n---@field run function")
  contains("---@field enabled boolean")
  contains("---@field inherited RexRuntimeInherited")
  contains("---@field delegated function")
  contains("---@field root RexRuntime")
  contains("---@class RexRuntimeCallable\n---@overload fun(...: any): any")
  contains('---@overload fun(creator: "com.example.terminal", method: "title", args: RexComExampleTerminalTitleArgs): RexComExampleTerminalTitleResult|nil, string?')
  contains("---@field title? string")
  assert(not output:find("---@class RexContext", 1, true), "handwritten context definition")
  assert(not output:find("---@class RexExecHandle", 1, true), "handwritten handle definition")
  assert(not output:find("---@class RexRemoteRuntime", 1, true), "handwritten remote definition")
  contains('---@overload fun(method: "session.list", args: RexSessionListArgs?): RexSessionListResult|nil, string?')
  contains('---@overload fun(method: "server.apple.privacy_status"')
  assert(not output:find("---@field list fun", 1, true), "nonexistent session helper")
  assert(not output:find("---@field apple.", 1, true), "RPC name used as a Lua field")
  assert(not output:find("---@field block_call", 1, true), "nonexistent block_call helper")
  schema.methods[1], schema.methods[3] = schema.methods[3], schema.methods[1]
  assert(output == generate(), "generation must be deterministic")
  schema.methods[3].output_schema.description = string.rep("Large schema documentation.\n", 10000)
  assert(#generate() > 250000, "large schemas must not overflow Rex's Lua registry")
end)
os.remove(output_path)
assert(ok, err)
print("Rex API generator regression checks passed")
