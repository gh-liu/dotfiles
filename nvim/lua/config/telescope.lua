local telescope = require('telescope')
telescope.setup {
    defaults = {
        layout_strategy = 'flex',
        scroll_strategy = 'cycle',
        mappings = {
            i = {
                ['<c-j>'] = require('telescope.actions').move_selection_next,
                ['<c-k>'] = require('telescope.actions').move_selection_previous,
                ['<ESC>'] = require('telescope.actions').close,
                ['<c-d>'] = require('telescope.actions').delete_buffer
            },
            n = {
                ['<c-j>'] = require('telescope.actions').move_selection_next,
                ['<c-k>'] = require('telescope.actions').move_selection_previous,
                ['<ESC>'] = require('telescope.actions').close,
                ['<c-d>'] = require('telescope.actions').delete_buffer
            }
        }
    },
    extensions = {
        fzf = {
            fuzzy = true, -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true, -- override the file sorter
            case_mode = "smart_case" -- or "ignore_case" or "respect_case", the default case_mode is "smart_case"

        }
    },
    pickers = {
        lsp_references = {
            theme = 'dropdown'
        },
        lsp_code_actions = {
            theme = 'dropdown'
        },
        lsp_definitions = {
            theme = 'dropdown'
        },
        lsp_implementations = {
            theme = 'dropdown'
        },
        buffers = {
            show_all_buffers = true,
            sort_lastused = true,
            previewer = false
        },
        live_grep = {
            theme = 'dropdown'
        }
    }
}

telescope.load_extension('fzf')
-- telescope.load_extension("frecency")
