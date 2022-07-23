local M = {}

local inlay_hints_ns = vim.api.nvim_create_namespace(
  "lsp_extensions.inlay_hints"
)

-- https://github.com/nvim-lua/lsp_extensions.nvim/blob/master/lua/lsp_extensions/util.lua
local function mk_handler(fn)
  return function(...)
    local config_or_client_id = select(4, ...)
    local is_new = type(config_or_client_id) ~= "number"
    if is_new then
      fn(...)
    else
      local err = select(1, ...)
      local method = select(2, ...)
      local result = select(3, ...)
      local client_id = select(4, ...)
      local bufnr = select(5, ...)
      local config = select(6, ...)
      fn(
        err,
        result,
        { method = method, client_id = client_id, bufnr = bufnr },
        config
      )
    end
  end
end

-- gopls
-- https://github.com/golang/tools/blob/master/gopls/doc/inlayHints.md
local inlay_hints_get_callback = function(opts)
  opts = opts or {}

  local highlight = opts.highlight or "Comment"
  local prefix = opts.prefix or " > "
  local aligned = opts.aligned or false

  local enabled = opts.enabled or { "ChainingHint" }

  local only_current_line = opts.only_current_line
  if only_current_line == nil then
    only_current_line = false
  end

  return mk_handler(function(err, result, ctx, _)
    print(err)
    print(gh.dump(result))
    print(gh.dump(ctx))

    -- I'm pretty sure this only happens for unsupported items.
    if err or type(result) == "number" then
      return
    end

    if not result or vim.tbl_isempty(result) then
      return
    end

    vim.api.nvim_buf_clear_namespace(ctx.bufnr, inlay_hints_ns, 0, -1)

    local hint_store = {}

    local longest_line = -1

    -- Check if something is in the list
    -- in_list({"ChainingHint"})("ChainingHint")
    local in_list = function(list)
      return function(item)
        for _, f in ipairs(list) do
          if f == item then
            return true
          end
        end

        return false
      end
    end

    for _, hint in ipairs(result) do
      local finish = hint.position.line
      if not hint_store[finish] then
        hint_store[finish] = hint

        if aligned then
          longest_line = math.max(
            longest_line,
            #vim.api.nvim_buf_get_lines(ctx.bufnr, finish, finish + 1, false)[1]
          )
        end
      end
    end

    local display_virt_text = function(hint)
      local end_line = hint.position.line
      local label = string.gsub(hint.label, "^:%s+", "")

      -- Check for any existing / more important virtual text on the line.
      -- TODO: Figure out how stackable virtual text works? What happens if there is more than one??
      local existing_virt_text = vim.api.nvim_buf_get_extmarks(
        ctx.bufnr,
        inlay_hints_ns,
        { end_line, 0 },
        { end_line, 0 },
        {}
      )
      if not vim.tbl_isempty(existing_virt_text) then
        return
      end

      local text
      if aligned then
        local line_length = #vim.api.nvim_buf_get_lines(
          ctx.bufnr,
          end_line,
          end_line + 1,
          false
        )[1]
        text = string.format(
          "%s %s",
          (" "):rep(longest_line - line_length),
          prefix .. label
        )
      else
        text = prefix .. label
      end
      vim.api.nvim_buf_set_extmark(ctx.bufnr, inlay_hints_ns, end_line, 0, {
        virt_text_pos = "eol",
        priority = 200,
        virt_text = { { text, highlight } },
        hl_mode = "combine",
      })
    end

    if only_current_line then
      local hint = hint_store[vim.api.nvim_win_get_cursor(0)[1] - 1]

      if not hint then
        return
      else
        display_virt_text(hint)
      end
    else
      for _, hint in pairs(hint_store) do
        display_virt_text(hint)
      end
    end
  end)
end

M.show_line_hints = function()
  -- TODO: add typescript
  -- https://github.com/jose-elias-alvarez/nvim-lsp-ts-utils/issues/40
  -- vim.lsp.buf_request(0, "typescript/inlayHints", params, inlay_hints_callback())

  local params = vim.lsp.util.make_given_range_params()
  params.range.start.line = 0
  params.range["end"].line = vim.api.nvim_buf_line_count(0) - 1

  vim.lsp.buf_request(
    0,
    "textDocument/inlayHint",
    params,
    inlay_hints_get_callback({ highlight = "LspCodeLens", prefix = "» " })
  )
end

local create_autocmd = vim.api.nvim_create_autocmd
M.setup = function()
  local show_line_hints = vim.api.nvim_create_augroup(
    "ShowLineHints",
    { clear = false }
  )
  create_autocmd({ "CursorHold", "CursorHoldI", "CursorMoved" }, {
    callback = function()
      M.show_line_hints()
    end,
    group = show_line_hints,
  })
end

return M
