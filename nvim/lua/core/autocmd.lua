local create_autocmd = vim.api.nvim_create_autocmd

create_autocmd("BufWinEnter", { command = [[checktime]] })
create_autocmd("BufReadPost", { command = [[normal! g`"]] })

create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 120 })
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
  local params = vim.lsp.util.make_range_params(0, "utf-16")
  params.context = { only = { "source.organizeImports" } }
  local result = vim.lsp.buf_request_sync(
    0,
    "textDocument/codeAction",
    params,
    wait_ms
  )
  -- print(vim.inspect(result))
  for _, res in pairs(result or {}) do
    for _, r in pairs(res.result or {}) do
      if r.kind == "source.organizeImports" then
        if r.edit then
          vim.lsp.util.apply_workspace_edit(r.edit, "utf-16")
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
    OrgImports(1000)
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
