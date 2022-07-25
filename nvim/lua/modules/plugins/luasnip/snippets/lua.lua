local ls = require("luasnip")
-- some shorthands...
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s("pcall", {
    t({ "local ok, _ = pcall(require, '" }),
    i(1),
    t({ "')", "if not ok then", "\t" }),
    i(0),
    t({ "", "end" }),
  }),
  s("fdm", {
    t({
      "-----------------------------------------------------------------------------//",
      "-- ",
    }),
    i(1),
    t({ " {{{" }),
    i(2),
    t({
      "",
      "-----------------------------------------------------------------------------//",
      "",
    }),
    i(0),
    t({ "", "-- }}}" }),
  }),
  s("fdmo", {
    t({
      "-- vim:foldmethod=marker",
    }),
  }),
}
