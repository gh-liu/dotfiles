if not pcall(require, "nvim-treesitter") then
  return
end

local tsconf = require("nvim-treesitter.configs")

tsconf.setup({
  ensure_installed = "all",
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
    lsp_interop = {
      enable = false,
    },
  },
  refactor = {
    highlight_definitions = {
      enable = true,
    },
    highlight_current_scope = {
      enable = false,
    },
    navigation = {
      enable = true,
      keymaps = {
        goto_next_usage = "<leader>j",
        goto_previous_usage = "<leader>k",
      },
    },
    smart_rename = {
      enable = false,
    },
  },
  rainbow = {
    enable = true,
    -- disable = { "jsx", "cpp" },
    extended_mode = true,
    max_file_lines = nil,
  },
  pairs = {
    enable = true,
  },
})
