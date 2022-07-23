local telescope = require("telescope")

local map = gh.map

-- File Pickers
map({ "n", "i" }, "<c-p>", [[<cmd>Telescope find_files<cr>]])
map("n", "<leader>fw", [[<cmd>Telescope grep_string<cr>]])
map("n", "<leader>ff", [[<cmd>Telescope live_grep<cr>]])

-- Vim Pickers
map({ "n", "i" }, "<c-b>", [[<cmd>Telescope buffers<cr>]])

map("n", "<leader>fh", [[<cmd>Telescope help_tags<cr>]])
map("n", "<leader>fm", [[<cmd>Telescope marks<cr>]])

-- Git Pickers
map({ "n", "i" }, "<c-g>", [[<cmd>Telescope git_status<cr>]])

-- Neovim LSP Pickers
map("n", "<leader>dw", [[<cmd>Telescope diagnostics<cr>]])
map("n", "<leader>db", [[<cmd>Telescope diagnostics bufnr=0<cr>]])

map("n", "<c-d>", [[<cmd>Telescope lsp_definitions<cr>]])
map("n", "gd", [[<cmd>Telescope lsp_definitions<cr>]])
map("n", "gD", [[<cmd>Telescope lsp_type_definitions<cr>]])

map("n", "gr", [[<cmd>Telescope lsp_references<cr>]])
map("n", "gi", [[<cmd>Telescope lsp_implementations<cr>]])

map("n", "<leader>g0", [[<cmd>Telescope lsp_document_symbols<cr>]])
map("n", "<leader>gW", [[<cmd>Telescope lsp_dynamic_workspace_symbols<cr>]])

map("n", ";", "<cmd>Telescope commands<cr>")

gh.command("Dotfiles", function()
  require("telescope.builtin").git_files({
    cwd = vim.env.HOME .. "/.config/nvim",
  })
end)

telescope.setup({
  defaults = {
    layout_strategy = "flex",
    scroll_strategy = "cycle",
    mappings = {
      i = {
        ["<c-j>"] = require("telescope.actions").move_selection_next,
        ["<c-k>"] = require("telescope.actions").move_selection_previous,
        ["<ESC>"] = require("telescope.actions").close,
        ["<c-d>"] = require("telescope.actions").delete_buffer,
        ["<c-q>"] = require("telescope.actions").close,
      },
      n = {
        ["<c-j>"] = require("telescope.actions").move_selection_next,
        ["<c-k>"] = require("telescope.actions").move_selection_previous,
        ["<ESC>"] = require("telescope.actions").close,
        ["<c-d>"] = require("telescope.actions").delete_buffer,
        ["<c-q>"] = require("telescope.actions").close,
      },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true, -- false will only do exact matching
      override_generic_sorter = true, -- override the generic sorter
      override_file_sorter = true, -- override the file sorter
      case_mode = "smart_case", -- or "ignore_case" or "respect_case", the default case_mode is "smart_case"
    },
  },
  pickers = {
    lsp_references = {
      theme = "dropdown",
    },
    lsp_code_actions = {
      theme = "dropdown",
    },
    lsp_definitions = {
      theme = "dropdown",
    },
    lsp_implementations = {
      theme = "dropdown",
    },
    buffers = {
      show_all_buffers = true,
      sort_lastused = true,
      -- previewer = false
    },
    live_grep = {
      theme = "dropdown",
    },
    file_browser = {
      -- 🗀📁
      dir_icon = "🗀",
    },
  },
})

require("telescope").load_extension("fzf")
