local on_attach = function(bufnr) end

require("aerial").setup({
  default_direction = "prefer_left",
  on_attach = on_attach,
})

gh.map("n", "T", [[<cmd>AerialToggle<cr>]])
