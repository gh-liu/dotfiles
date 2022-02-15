local opt = as.opt

opt("background", "dark")
vim.cmd([[colorscheme gruvbox-material]])
--  Set contrast.
--  This configuration option should be placed before `colorscheme gruvbox-material`.
--  Available values: 'hard', 'medium'(default), 'soft'
vim.g.gruvbox_material_background = "hard"

-- vim.cmd([[colorscheme codedark]])
