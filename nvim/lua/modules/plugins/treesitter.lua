if not pcall(require, "nvim-treesitter") then
  return
end

local tsconf = require("nvim-treesitter.configs")

tsconf.setup({
  -- ensure_installed = {
  --   "comment",
  --   "go",
  --   "gomod",
  --   "vim",
  --   "bash",
  --   "lua",
  --   "json",
  --   "json5",
  --   "yaml",
  --   "toml",
  --   "dockerfile",
  --   "query",
  --   "markdown",
  --   "rust",
  --   "javascript",
  --   "typescript",
  -- },
  ensure_installed = "maintained",
  sync_install = false, -- install languages synchronously (only applied to `ensure_installed`)
  ignore_install = {}, -- List of parsers to ignore installing
  highlight = {
    enable = true,
    disable = {},
    additional_vim_regex_highlighting = false,
  },
  indent = {
    enable = true,
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",

        ["ac"] = "@conditional.outer",
        ["ic"] = "@conditional.inner",

        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ["<leader><leader>a"] = "@parameter.inner",
      },
      swap_previous = {
        ["<leader><leader>A"] = "@parameter.inner",
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        ["]p"] = "@parameter.inner",
        ["]]"] = "@function.outer",
      },
      goto_previous_start = {
        ["[p"] = "@parameter.inner",
        ["[["] = "@function.outer",
      },
    },
  },
  refactor = {
    highlight_definitions = {
      enable = true,
    },
    navigation = {
      enable = false,
      keymaps = {
        goto_definition = "gnd", -- mapping to go to definition of symbol under cursor
        list_definitions = "gnD", -- mapping to list all definitions in current file
      },
    },
  },
  rainbow = {
    enable = true,
    -- disable = { "jsx", "cpp" },
    extended_mode = true,
    max_file_lines = nil,
  },
})
