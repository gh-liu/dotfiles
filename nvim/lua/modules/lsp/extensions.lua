local create_autocmd = as.create_autocmd

local M = {}

local lightbulb_line = nil
-- inspired by https://github.com/kosayoda/nvim-lightbulb
M.lightbulb = function(client, bufnr)
  local events = { "CursorHold", "CursorHoldI" }
  local method = "textDocument/codeAction"

  local sign_group = "_lightbulb"
  local sign_name = "LightBulbSign"
  local sign_priority = 10
  local sign_attr = { text = "↑", texthl = "", linehl = "", numhl = "" }

  -- check if len(clients)>0
  client = client or vim.lsp.buf_get_clients()[0]
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if client.supports_method(method) then
    local cur_line = nil

    vim.fn.sign_define(sign_name, sign_attr)

    -- lsp request callback
    local req_callback = function(responses)
      -- update_sign
      local function update_sign(line)
        if lightbulb_line then
          vim.fn.sign_unplace(
            sign_group,
            { id = lightbulb_line, buffer = bufnr }
          )
          lightbulb_line = nil
        end

        -- Avoid redrawing lightbulb if code action line did not change
        if line and (lightbulb_line ~= line) then
          vim.fn.sign_place(
            line,
            sign_group,
            sign_name,
            bufnr,
            { lnum = line, sign_priority = sign_priority }
          )
          -- Update current lightbulb line
          lightbulb_line = line
        end
      end

      local has_actions = false
      for client_id, resp in pairs(responses) do
        if resp.result and not vim.tbl_isempty(resp.result) then
          has_actions = true
          break
        end
      end
      if not has_actions then
        update_sign()
      else
        update_sign(cur_line + 1)
      end
    end

    -- lsp request
    local request = function()
      local context = {
        diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
      }
      local params = vim.lsp.util.make_range_params(0)
      params.context = context

      cur_line = params.range.start.line

      vim.lsp.buf_request_all(bufnr, method, params, req_callback)
    end

    -- auto command
    -- local light_bulb = vim.api.nvim_create_augroup(
    --   "light_bulb",
    --   { clear = true }
    -- )
    create_autocmd(events, {
      buffer = bufnr,
      callback = request,
      -- group = light_bulb,
    })
  end
end

return M
