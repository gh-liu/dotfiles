local autocmd = as.autocmd

autocmd("_general", {
  [[BufWinEnter * checktime]],
  [[TextYankPost * silent! lua vim.highlight.on_yank({higroup="IncSearch", timeout=150})]],
  [[FileType qf set nobuflisted ]],
  [[BufReadPost * normal! g`" ]],
}, true)

function helptab()
  if vim.o.buftype == "help" then
    vim.cmd([[wincmd T]])
    vim.api.nvim_buf_set_keymap("0", "n", "q", "<cmd>q<cr>", {
      silent = true,
      noremap = true,
    })
  end
end
autocmd("_open_help_tab", { [[BufEnter *.txt lua helptab()]] }, true)

-- filetype
vim.api.nvim_command("filetype plugin indent on")

autocmd("_protobuf", {
  [[ BufNewFile,BufRead *.proto setfiletype proto ]],
  [[ FileType proto setlocal shiftwidth=2 expandtab ]],
}, true)

autocmd(
  "_json",
  { [[FileType json setlocal tabstop=2 shiftwidth=2 softtabstop=2 expandtab ]] },
  true
)

autocmd("_markdown", { [[FileType markdown setlocal cole=0]] }, true)

autocmd("_tmux", { [[FileType tmux setlocal foldmethod=marker]] }, true)

autocmd("_go", { [[ BufNewFile,BufRead *.gotmpl set ft=gotmpl]] }, true)


function goimports(timeout_ms)
  local context = {
    only = { "source.organizeImports" },
  }
  vim.validate({
    context = { context, "t", true },
  })

  local params = vim.lsp.util.make_range_params()
  params.context = context

  -- See the implementation of the textDocument/codeAction callback
  -- (lua/vim/lsp/handler.lua) for how to do this properly.
  local result = vim.lsp.buf_request_sync(
    0,
    "textDocument/codeAction",
    params,
    timeout_ms
  )
  if not result or next(result) == nil then
    return
  end
  local actions = result[1].result
  if not actions then
    return
  end
  local action = actions[1]

  -- textDocument/codeAction can return either Command[] or CodeAction[]. If it
  -- is a CodeAction, it can have either an edit, a command or both. Edits
  -- should be executed first.
  if action.edit or type(action.command) == "table" then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit)
    end
    if type(action.command) == "table" then
      vim.lsp.buf.execute_command(action.command)
    end
  else
    vim.lsp.buf.execute_command(action)
  end
end

as.autocmd("goimports", { [[BufWritePre *.go lua goimports(1000)]] }, true)
