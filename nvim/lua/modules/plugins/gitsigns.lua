local gitsigns = require("gitsigns")

local line = vim.fn.line

local function on_attach(bufnr)
  local function map(modes, lhs, rhs, opts)
    opts = vim.tbl_extend(
      "force",
      { noremap = true, silent = true },
      opts or {}
    )
    if type(modes) == "string" then
      modes = { modes }
    end

    for _, mode in ipairs(modes) do
      vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)
    end
  end

  map(
    "n",
    "]c",
    "&diff ? ']c' : '<cmd>Gitsigns next_hunk<CR>'",
    { expr = true }
  )
  map(
    "n",
    "[c",
    "&diff ? '[c' : '<cmd>Gitsigns prev_hunk<CR>'",
    { expr = true }
  )

  map({ "n", "v" }, "<leader>hs", ":Gitsigns stage_hunk<CR>")
  map({ "n", "v" }, "<leader>hr", ":Gitsigns reset_hunk<CR>")
  map("n", "<leader>hu", "<cmd>Gitsigns undo_stage_hunk<CR>")
  map("n", "<leader>hR", "<cmd>Gitsigns reset_buffer<CR>")
  map("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<CR>")
  map("n", "<leader>hb", '<cmd>lua require"gitsigns".blame_line{full=true}<CR>')
  map("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<CR>")
  map("n", "<leader>hd", "<cmd>Gitsigns diffthis<CR>")
  map("n", "<leader>hD", '<cmd>lua require"gitsigns".diffthis("~")<CR>')

  map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
end

gitsigns.setup({
  max_file_length = 1000000000,
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
  current_line_blame = true,
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
