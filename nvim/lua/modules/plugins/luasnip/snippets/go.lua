---@diagnostic disable: undefined-global

-- args is a table, where 1 is the text in Placeholder 1, 2 the text in
-- placeholder 2,...
local function copy(args)
  return args[1]
end

return {
  s("func", {
    t("// "),
    f(copy, 1),
    t(" "),
    i(0),
    t({ " ", "func " }),
    i(1),
    t("("),
    i(2),
    t({ ") " }),
    i(3),
    t({ "{", " " }),
    t("\t"),
    i(4),
    t({ "", "}" }),
  }),
  s(
    { trig = "pr", name = "print var", dscr = "Print a variable" },
    fmt("fmt.Println({})", {
      i(1, "value"),
    })
  ),
  s("ctx", {
    t("ctx context.Context"),
  }),
},
  nil
