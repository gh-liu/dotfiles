local gitsigns = require("gitsigns")

local function on_attach(bufnr)
  local gs = package.loaded.gitsigns

  local function map(mode, l, r, opts)
    opts = opts or {}
    opts.buffer = bufnr
    vim.keymap.set(mode, l, r, opts)
  end

  -- Navigation
  map("n", "]c", function()
    if vim.wo.diff then
      return "]c"
    end
    vim.schedule(function()
      gs.next_hunk()
    end)
    return "<Ignore>"
  end, { expr = true })

  map("n", "[c", function()
    if vim.wo.diff then
      return "[c"
    end
    vim.schedule(function()
      gs.prev_hunk()
    end)
    return "<Ignore>"
  end, { expr = true })

  -- Actions
  map({ "n", "v" }, "<leader>hs", ":Gitsigns stage_hunk<CR>")
  map({ "n", "v" }, "<leader>hr", ":Gitsigns reset_hunk<CR>")
  map("n", "<leader>hp", gs.preview_hunk)
  map("n", "<leader>hb", function()
    gs.blame_line({ full = true })
  end)
  map("n", "<leader>tb", gs.toggle_current_line_blame)
  -- map('n', '<leader>hu', gs.undo_stage_hunk)
  -- map('n', '<leader>hR', gs.reset_buffer)
  map("n", "<leader>hd", gs.diffthis)
  map("n", "<leader>hD", function()
    gs.diffthis("~")
  end)

  map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
end

gitsigns.setup({
  max_file_length = 40000,
  signs = {
    add = { show_count = false, text = "┃" },
    change = { show_count = false, text = "¦" },
    delete = { show_count = true },
    topdelete = { show_count = true },
    changedelete = { show_count = true },
  },
  on_attach = on_attach,
  preview_config = {
    border = "rounded",
  },
  current_line_blame = false,
  current_line_blame_formatter_opts = {
    relative_time = true,
  },
  current_line_blame_opts = {
    delay = 0,
  },
  count_chars = {
    "⒈",
    "⒉",
    "⒊",
    "⒋",
    "⒌",
    "⒍",
    "⒎",
    "⒏",
    "⒐",
    "⒑",
    "⒒",
    "⒓",
    "⒔",
    "⒕",
    "⒖",
    "⒗",
    "⒘",
    "⒙",
    "⒚",
    "⒛",
  },
  _refresh_staged_on_update = false,
  -- word_diff = true,
})
