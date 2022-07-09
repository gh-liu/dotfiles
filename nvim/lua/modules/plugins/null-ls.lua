-- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTINS.md
-- https://github.com/jose-elias-alvarez/null-ls.nvim/blob/main/doc/BUILTIN_CONFIG.md
local null_ls = require("null-ls")

local b = null_ls.builtins

-- local with_root_file = function(...)
--   local files = { ... }
--   return function(utils)
--     return utils.root_has_file(files)
--   end
-- end

local sources = {
  -- b.formatting.stylua.with({
  --   condition = with_root_file("stylua.toml"),
  -- }),
  -- b.formatting.goimports,

  b.formatting.mdformat,
  b.diagnostics.golangci_lint,
}

null_ls.setup({ sources = sources })

local methods = require("null-ls.methods")
local CODE_ACTION = methods.internal.CODE_ACTION
local git_sign = {
  method = CODE_ACTION,
  filetypes = {},
  generator = {
    fn = function(params)
      local ok, gitsigns_actions = pcall(require("gitsigns").get_actions)
      if not ok or not gitsigns_actions then
        return
      end

      local name_to_title = function(name)
        return name:sub(1, 1):upper() .. name:gsub("_", " "):sub(2)
      end

      local actions = {}
      for name, action in pairs(gitsigns_actions) do
        -- I do not need the blame line action
        if name ~= "blame_line" then
          table.insert(actions, {
            title = name_to_title(name),
            action = function()
              vim.api.nvim_buf_call(params.bufnr, action)
            end,
          })
        end
      end
      return actions
    end,
  },
}
null_ls.register(git_sign)

-- https://github.com/vanhtuan0409/dotfiles/blob/master/config/nvim/lua/modules/nullls/go/code_actions.lua
local log = require("null-ls.logger")
local loop = require("null-ls.loop")
local c = require("null-ls.config")
local u = require("null-ls.utils")
local nclient = require("null-ls.client")

local extract_struct_name = function(params)
  local linenr = params.row
  local line = params.content[linenr]
  return line:match("^type (.*) struct")
end

local prompt_tag_name = function()
  return vim.fn.input("Enter struct tag: ")
end

local save_on_return = true
local gomodifytags = {
  name = "gomodifytags",
  meta = {
    url = "https://github.com/fatih/gomodifytags",
    description = "Go tool to modify struct field tags",
  },
  method = CODE_ACTION,
  filetypes = { "go" },
  generator = {
    fn = function(params)
      local replace_buf = function(ps)
        local output = ps.action_output
        vim.lsp.util.apply_text_edits(
          { {
            range = u.range.to_lsp({
              row = 1,
              col = 1,
              end_row = vim.tbl_count(ps.content) + 1,
              end_col = 1,
            }),
            newText = output:gsub("[\r\n]$", ""),
          } },
          ps.bufnr,
          nclient.get_offset_encoding()
        )
      end

      local make_cli_handler = function(ac)
        return function(error_output, output)
          log:debug("error output: " .. (error_output or "nil"))
          log:debug("output: " .. (output or "nil"))

          if not output then
            return
          end

          -- perform output processing
          params.action_output = output
          ac.on_output(params)

          if save_on_return then
            vim.schedule(function()
              vim.cmd(params.bufnr .. "bufdo! silent keepjumps noautocmd update")
            end)
          end
        end
      end

      local invoke_cli = function(ac)
        local command = ac.command
        local args = ac.args
        local timeout = ac.timeout or c.get().default_timeout
        local stdin = ac.stdin or false
        assert(
          vim.fn.executable(command) > 0,
          string.format("command %s is not executable (make sure it's installed and on your $PATH)", command)
        )

        local client = vim.lsp.get_client_by_id(params.client_id)
        local spawn_opts = {
          cwd = client and client.config.root_dir or vim.fn.getcwd(),
          input = nil,
          handler = make_cli_handler(ac),
          timeout = timeout,
        }
        if stdin then
          local content = table.concat(params.content, "\n")
          spawn_opts["input"] = content
        end

        log:debug("spawning command " .. command .. " with args:")
        log:debug(args)
        loop.spawn(command, args, spawn_opts)
      end

      local action_fn = function(ps)
        local typ = extract_struct_name(ps)
        if not typ then
          return
        end
        local command = "gomodifytags"
        local actions = {
          {
            title = "[gomodifytags] Add struct tags",
            dynamic_action = function(invoke_c)
              local tag = prompt_tag_name()
              if not tag then
                return
              end
              invoke_c({
                command = command,
                args = {
                  "-file",
                  ps.bufname,
                  "-struct",
                  typ,
                  "-skip-unexported",
                  "-add-tags",
                  tag,
                },
                on_output = replace_buf,
              })
            end,
          },
          {
            title = "[gomodifytags] Remove struct tags",
            dynamic_action = function(invoke_cl)
              local tag = prompt_tag_name()
              if not tag then
                return
              end
              invoke_cl({
                command = command,
                args = {
                  "-file",
                  ps.bufname,
                  "-struct",
                  typ,
                  "-skip-unexported",
                  "-remove-tags",
                  tag,
                },
                on_output = replace_buf,
              })
            end,
          },
          {
            title = "[gomodifytags] Clear struct tags",
            command = command,
            on_output = replace_buf,
            args = { "-file", ps.bufname, "-struct", typ, "-skip-unexported", "-clear-tags" },
          },
        }
        return actions
      end

      local action_list = action_fn(params)
      if not action_list then
        return
      end

      local actions = {}
      for _, action in pairs(action_list) do
        table.insert(actions, {
          title = action.title,
          action = function()
            if action.dynamic_action then
              action.dynamic_action(invoke_cli)
            else
              invoke_cli(action)
            end
          end,
        })
      end

      return actions
    end,
  },
}
null_ls.register(gomodifytags)
