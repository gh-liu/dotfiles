local create_autocmd = vim.api.nvim_create_autocmd

create_autocmd("BufWinEnter", { command = [[checktime]] })
create_autocmd("BufReadPost", { command = [[normal! g`"]] })

create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 120 })
  end,
})

create_autocmd({ "VimResized" }, {
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- open help page in a window
create_autocmd("BufEnter", {
  pattern = "*.txt",
  callback = function()
    if vim.bo.buftype == "help" then
      vim.api.nvim_command([[wincmd T]])
    end
  end,
})

-- To get your imports ordered on save
function OrgImports(wait_ms)
  local clients = vim.lsp.get_active_clients()
  for _, client in pairs(clients) do
    if client.config.name == "gopls" then
      local offset_encoding = "utf-16"
      local method = "textDocument/codeAction"
      local bufnr = vim.api.nvim_get_current_buf()
      local params = vim.lsp.util.make_range_params(0, offset_encoding)
      params.context = { only = { "source.organizeImports" } }

      local ret = client.request_sync(method, params, wait_ms, bufnr) or {}
      for _, r in pairs(ret.result or {}) do
        if r.edit then
          vim.lsp.util.apply_workspace_edit(r.edit, offset_encoding)
        else
          vim.lsp.buf.execute_command(r.command)
        end
      end
    end
  end
end

create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function()
    OrgImports(5000)
  end,
})

-- toggle line num on or exit insert mode
local toggle_line_num_on_insert = vim.api.nvim_create_augroup(
  "toggle_line_num_on_insert",
  { clear = false }
)
create_autocmd(
  "InsertEnter",
  { command = [[set norelativenumber]], group = toggle_line_num_on_insert }
)
create_autocmd(
  "InsertLeave",
  { command = [[set relativenumber]], group = toggle_line_num_on_insert }
)

-- trim trailing white space
local trim_trailing = vim.api.nvim_create_augroup(
  "trim_trailing",
  { clear = true }
)
create_autocmd(
  "BufWritePre",
  { command = [[%s/\s\+$//e]], group = trim_trailing }
)
create_autocmd(
  "BufWritePre",
  { command = [[%s/\s\+$//e]], group = trim_trailing }
)

-- Cursorline highlighting control
local cursorline_group = vim.api.nvim_create_augroup(
  "CursorLineControl",
  { clear = true }
)
local set_cursorline = function(event, value, pattern)
  create_autocmd(event, {
    group = cursorline_group,
    pattern = pattern,
    callback = function()
      vim.opt_local.cursorline = value
    end,
  })
end
set_cursorline("WinLeave", false)
set_cursorline("WinEnter", true)
set_cursorline("FileType", false, "TelescopePrompt")

-- signcolumn control
local signcolumn_group = vim.api.nvim_create_augroup(
  "SigncolumnControl",
  { clear = true }
)
local set_signcolumn = function(event, value, pattern)
  create_autocmd(event, {
    group = signcolumn_group,
    pattern = pattern,
    callback = function()
      vim.opt_local.signcolumn = value
    end,
  })
end
set_signcolumn("FileType", "no", { "TelescopePrompt", "Outline" })
set_signcolumn({ "BufWinEnter", "InsertEnter" }, "yes:2", {})

-- wrap control
local wrap_group = vim.api.nvim_create_augroup("WrapControl", { clear = true })
local set_warp = function(event, value, pattern)
  create_autocmd(event, {
    group = wrap_group,
    pattern = pattern,
    callback = function()
      vim.opt_local.wrap = value
    end,
  })
end
set_warp("FileType", false, { "TelescopePrompt", "code-action-menu-menu" })
