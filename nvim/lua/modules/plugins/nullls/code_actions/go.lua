-- https://github.com/vanhtuan0409/dotfiles/blob/master/config/nvim/lua/modules/nullls/go/code_actions.lua
local null_ls = require("null-ls")
local log = require("null-ls.logger")
local loop = require("null-ls.loop")
local c = require("null-ls.config")
local u = require("null-ls.utils")
local nclient = require("null-ls.client")

local ts_utils = require("nvim-treesitter.ts_utils")
local query = require("vim.treesitter.query")

local CODE_ACTION = null_ls.methods.CODE_ACTION

local extract_struct_name = function(params)
  local linenr = params.row
  local line = params.content[linenr]
  return line:match("^type (.*) struct")
end

local prompt_tag_name = function()
  return vim.fn.input("Enter struct tag: ")
end

local make_action_name = function(cmd)
  return "[" .. cmd.command .. "] " .. cmd.title
end

local make_action = function(cmd, nulllsparams, opt)
  opt = opt or {}
  local command = cmd.command
  assert(
    vim.fn.executable(command) > 0,
    string.format(
      "command %s is not executable (make sure it's installed and on your $PATH)",
      command
    )
  )
  local args = cmd.args
  local timeout = cmd.timeout or c.get().default_timeout
  local stdin = cmd.stdin or false

  local params = nulllsparams or {}

  local if_save_on_return = opt.save_on_return or false

  local output_handler = function(error_output, output)
    log:debug("error output: " .. (error_output or "nil"))
    log:debug("output: " .. (output or "nil"))

    if not output then
      return
    end

    -- perform output processing
    if cmd.on_output then
      params.cmd_output = output
      cmd.on_output(params)
    end

    if if_save_on_return then
      vim.schedule(function()
        vim.cmd(params.bufnr .. "bufdo! silent keepjumps noautocmd update")
      end)
    end
  end

  local client = vim.lsp.get_client_by_id(params.client_id)
  local spawn_opts = {
    cwd = client and client.config.root_dir or vim.fn.getcwd(),
    input = nil,
    handler = output_handler,
    timeout = timeout,
  }

  if stdin then
    local content = table.concat(params.content, "\n")
    spawn_opts["input"] = content
  end

  local action = function()
    log:debug("spawning command " .. command .. " with args:")
    log:debug(args)
    loop.spawn(command, args, spawn_opts)
  end

  return action
end

local make_actions = function(cmds, params, opts)
  local actions = {}
  for _, cmd in pairs(cmds) do
    local fn
    if cmd.dynamic_action then
      fn = function()
        cmd.dynamic_action(make_action)
      end
    else
      fn = make_action(cmd, params, opts)
    end

    table.insert(actions, {
      title = make_action_name(cmd),
      action = fn,
    })
  end
  return actions
end

local replace_buf = function(ps)
  local output = ps.cmd_output
  vim.lsp.util.apply_text_edits({
    {
      range = u.range.to_lsp({
        row = 1,
        col = 1,
        end_row = vim.tbl_count(ps.content) + 1,
        end_col = 1,
      }),
      newText = output:gsub("[\r\n]$", ""),
    },
  }, ps.bufnr, nclient.get_offset_encoding())
end

local M = {}
M.gomodifytags = {
  name = "gomodifytags",
  meta = {
    url = "https://github.com/fatih/gomodifytags",
    description = "Go tool to modify struct field tags",
  },
  method = CODE_ACTION,
  filetypes = { "go" },
  generator = {
    fn = function(params)
      local typ = extract_struct_name(params)
      if not typ then
        return
      end

      local command = "gomodifytags"
      local cmds = {
        {
          title = "Add struct tags",
          command = command,
          dynamic_action = function(make_ac)
            local tag = prompt_tag_name()
            if not tag then
              return
            end
            local fn = make_ac({
              command = command,
              args = {
                "-file",
                params.bufname,
                "-struct",
                typ,
                "-skip-unexported",
                "-add-tags",
                tag,
              },
              on_output = replace_buf,
            }, params, { save_on_return = true })
            fn()
          end,
        },
        {
          title = "Remove struct tags",
          command = command,
          dynamic_action = function(make_ac)
            local tag = prompt_tag_name()
            if not tag then
              return
            end
            local fn = make_ac({
              command = command,
              args = {
                "-file",
                params.bufname,
                "-struct",
                typ,
                "-skip-unexported",
                "-remove-tags",
                tag,
              },
              on_output = replace_buf,
            }, params, { save_on_return = true })
            fn()
          end,
        },
        {
          title = "Clear struct tags",
          command = command,
          args = {
            "-file",
            params.bufname,
            "-struct",
            typ,
            "-skip-unexported",
            "-clear-tags",
          },
          on_output = replace_buf,
        },
      }

      return make_actions(cmds, params, { save_on_return = true })
    end,
  },
}

M.gotests = {
  name = "gotests",
  meta = {
    url = "https://github.com/cweill/gotests",
    description = "Automatically generate Go test boilerplate from your source code.",
  },
  method = CODE_ACTION,
  filetypes = { "go" },
  generator = {
    fn = function(params)
      local bufname = params.bufname
      if bufname:match("_test.go$") then
        return
      end

      local tsnode = ts_utils.get_node_at_cursor()
      if not tsnode then
        return
      end

      tsnode = tsnode:parent()
      if not tsnode then
        return
      end
      local nodetype = tsnode:type()

      if
        nodetype ~= "method_declaration"
        and nodetype ~= "function_declaration"
      then
        return
      end

      local funcname = ""
      if nodetype == "function_declaration" then
        funcname = query.get_node_text(tsnode:child(1), 0)
      end
      -- if nodetype == "method_declaration" then
      --   local rec = tsnode:child(1):child(1):child(2)
      --   print(query.get_node_text(rec, 0))
      --   -- funcname = query.get_node_text(tsnode:child(2), 0)
      -- end

      --   local params = {
      --     content, -- current buffer content (table, split at newline)
      --     lsp_method, -- lsp method that triggered request (string)
      --     method, -- null-ls method that triggered generator (string)
      --     row, -- cursor's current row (number, zero-indexed)
      --     col, -- cursor's current column (number)
      --     bufnr, -- current buffer's number (number)
      --     bufname, -- current buffer's full path (string)
      --     ft, -- current buffer's filetype (string)
      --     root, -- current buffer's root directory (string)
      -- }
      local on_output = function(ps)
        local output = ps.cmd_output
        -- fail: No tests generated for
        -- success: Generated TestGetDB
        if output:match("Generated (.*)") then
          print(output)
        end
        if output:match("No tests generated for (.*)") then
          print("test function already exist")
        end
      end

      local command = "gotests"
      local cmds = {
        {
          title = "Generate Unit Tests For Function",
          command = command,
          args = { "-w", "-only", funcname, bufname },
          on_output = on_output,
        },
      }
      return make_actions(cmds, params, {})
    end,
  },
}

return M
